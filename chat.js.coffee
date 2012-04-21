Messages = new Meteor.Collection "messages"
Rooms    = new Meteor.Collection "rooms"

room = ->
  return Rooms.findOne(Session.get('roomID'))

all_rooms = ->
  rooms = Rooms.find({}, { sort: {time: -1}}).fetch()
  return rooms.slice(0,5).reverse()

is_in_room = ->
  return Session.get("roomID")

root = global ? window

if root.Meteor.is_client
  window.Messages = Messages
  window.Rooms = Rooms

  root.Template.hello.greeting = ->
    "Welcome to Chat with Rooms"

  Template.existing_rooms.rooms = ->
    return all_rooms()

  Template.room.events =
    'click #create_room_submit': (event) ->
      event.preventDefault()
      room_name = $("#create_room_name").val()
      if room_name == ""
        $("#create_room_errors").html("Type in a name buddy")
      else
        $("#create_room_errors").html("")
        room = Rooms.insert
          name: room_name
          created: new Date()
        Session.set("roomID", room)
      return false

    'click #leave_room': (event) ->
      event.preventDefault()
      Session.set("roomID", "")

  Template.room_link.events =
    'click .room_link': (event) ->
      event.preventDefault()
      Session.set("roomID", $(this).attr("_id"))
      return false

  Template.room.room_name = ->
    room = Rooms.findOne(Session.get('roomID'))
    return room.name


  Template.room.is_in_room = ->
    return is_in_room();

    # Load all documents in messages collection from Mongo
  Template.messages.messages = -> 
    roomID = Session.get("roomID")
    Messages.find({'roomID': roomID}, { sort: {time: -1} })

  # Listen for the following events on the entry template
  Template.entry.events =
    # All keyup events from the #messageBox element
    'keyup #messageBox': (event) ->
      if event.type == "keyup" && event.which == 13 # [ENTER]
        new_message = $("#messageBox")
        name = $("#name")

        # Save values into Mongo
        Messages.insert
          name: name.val(),
          roomID: Session.get("roomID"),
          message: new_message.val(),
          created: new Date()

        # Clear the input boxes
        new_message.val("")
        new_message.focus()

        # Make sure new chat messages are visible
        $("#chat").scrollTop 9999999;