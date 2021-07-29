User.destroy_all

User.create!([{
  name: "Frank",
  username: "olblueeyes",
  email: "example@email.com",
  password: "frank"
  }])
  

Contact.destroy_all

Contact.create!([{
name: "John Smith",
phone_number: "+15555555555"
}])

Broadcast.destroy_all

Broadcast.create!([{
subject: "Broadcast Title",
body: "Fly me to the moon. Let me play among the stars and let me see what spring is like on a-Jupiter and Mars. In other words, hold my hand. In other words, baby, kiss me",
broadcast: "false"
}])
