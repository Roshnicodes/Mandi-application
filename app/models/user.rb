begin
  require "bcrypt"
rescue LoadError
  bcrypt_lib = Dir[Rails.root.join("vendor/bundle/ruby/*/gems/bcrypt-*/lib").to_s].max
  raise unless bcrypt_lib

  $LOAD_PATH.unshift(bcrypt_lib) unless $LOAD_PATH.include?(bcrypt_lib)
  require "bcrypt"
end

class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
end
