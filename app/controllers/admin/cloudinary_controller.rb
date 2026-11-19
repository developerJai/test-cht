class Admin::CloudinaryController < ApplicationController
  before_action :authorized
  before_action :set_current_user
  before_action :require_admin

  MAX_RESOURCES = 100

  # Folder names here are built from usernames, so keep it to characters a
  # username can produce plus the separator.
  SAFE_PATH = %r{\A[A-Za-z0-9 _\-/.]*\z}

  def index
    @path   = params[:path].to_s.strip.gsub(%r{\A/+|/+\z}, "")
    @path   = "" unless @path.match?(SAFE_PATH)
    @crumbs = build_crumbs(@path)

    # Every URL any message still points at, so we can mark the rest as orphans.
    @linked_urls = Message.where.not(image: nil).filter_map { |m| m.image.presence }

    begin
      @folders   = fetch_folders
      @resources = fetch_resources
      @error     = nil
    rescue StandardError => e
      @folders   = []
      @resources = []
      @error     = "#{e.class}: #{e.message}"
    end
  end

  # Deletes the file from Cloudinary itself. Irreversible, so the button
  # carries a confirm and the message says whether a chat still points at it.
  def destroy
    public_id = params[:public_id].to_s
    kind      = params[:resource_type].to_s
    kind      = "image" unless %w[image video].include?(kind)
    back      = params[:path].to_s

    if public_id.blank? || !public_id.match?(SAFE_PATH)
      flash[:error] = "That file id is not valid. Nothing was deleted."
      return redirect_to admin_cloudinary_path(path: back)
    end

    begin
      result = Cloudinary::Uploader.destroy(public_id, resource_type: kind, invalidate: true)

      if result["result"] == "ok"
        flash[:success] = "Deleted #{public_id} from Cloudinary."
      elsif result["result"] == "not found"
        flash[:error] = "Cloudinary has no file called #{public_id}."
      else
        flash[:error] = "Cloudinary said: #{result["result"]}"
      end
    rescue StandardError => e
      flash[:error] = "Could not delete #{public_id} - #{e.class}: #{e.message}"
    end

    redirect_to admin_cloudinary_path(path: back)
  end

  private

  def set_current_user
    @current_user = current_user
  end

  def require_admin
    unless @current_user.admin?
      flash[:error] = "Access denied. Admin privileges required."
      redirect_to dashboard_path
    end
  end

  # Cloudinary returns the hourly Admin API allowance on every response.
  def capture_rate_limit(response)
    return unless response.respond_to?(:rate_limit_remaining)

    @rate_allowed   = response.rate_limit_allowed
    @rate_remaining = response.rate_limit_remaining
    @rate_reset_at  = response.rate_limit_reset_at
  rescue StandardError
    nil
  end

  def build_crumbs(path)
    return [] if path.blank?

    parts = path.split("/")
    parts.each_with_index.map do |part, i|
      { name: part, path: parts[0..i].join("/") }
    end
  end

  def fetch_folders
    response = @path.blank? ? Cloudinary::Api.root_folders : Cloudinary::Api.subfolders(@path)
    capture_rate_limit(response)
    Array(response["folders"])
  end

  def fetch_resources
    rows = %w[image video].flat_map do |kind|
      options = { type: "upload", resource_type: kind, max_results: MAX_RESOURCES }
      options[:prefix] = "#{@path}/" if @path.present?

      response = Cloudinary::Api.resources(**options)
      capture_rate_limit(response)

      Array(response["resources"]).map do |r|
        r.merge("resource_type" => kind)
      end
    end

    # At the root, only show files that are not inside a folder - the folders
    # themselves are listed separately.
    rows = rows.reject { |r| r["public_id"].to_s.include?("/") } if @path.blank?

    rows.each do |r|
      pid = r["public_id"].to_s
      r["_orphan"] = pid.blank? || @linked_urls.none? { |url| url.include?(pid) }
    end

    rows.sort_by { |r| r["created_at"].to_s }.reverse
  end

end
