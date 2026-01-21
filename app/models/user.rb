class User < ApplicationRecord
  has_secure_password

  has_many :messages
  has_many :removed_texts

  validates :username, presence: true, uniqueness: true
  validates :password, length: { minimum: 6 }, if: :password_digest_changed?

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :non_admin, -> { where(is_admin: [false, nil]) }

  def admin?
    is_admin == true || username == "qwert"
  end

  def self.admin_user
    find_by(username: "qwert")
  end

  def status_label
    enabled? ? "Active" : "Disabled"
  end

  def enabled?
    enabled == true
  end

  def toggle_status!
    update(enabled: !enabled)
  end
end
