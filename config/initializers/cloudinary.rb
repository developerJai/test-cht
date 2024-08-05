require 'cloudinary'

Cloudinary.config_from_url("cloudinary://#{ENV['CLOUDINARY_API_KEY']}:#{ENV['CLOUDINARY_API_SECRET']}@#{ENV['CLOUDINARY_CLOUD_NAME']}")