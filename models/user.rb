class User < ActiveRecord::Base
  has_many :broadcasts
  has_secure_password
  
end