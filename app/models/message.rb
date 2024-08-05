class Message < ApplicationRecord
  belongs_to :user
  scope :without_images, -> {
    where("image is null")
  }

  scope :clean, -> {
    without_images.delete_all
  }
end
