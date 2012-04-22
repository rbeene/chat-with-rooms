Messages = new Meteor.Collection "messages"
Rooms    = new Meteor.Collection "rooms"
Users     = new Meteor.Collection "users"

room = ->
  return Rooms.findOne(Session.get('roomID'))

local_time_stamp = (time) ->
  obj     = new Date(time)
  minutes = obj.getMinutes()
  if minutes < 10
    minutes = "0" + minutes
  "#{obj.getMonth()+ 1}/#{obj.getDate()}/#{obj.getFullYear()} @ #{obj.getHours()}:#{minutes}"

utc_time_stamp = ()->
  time = new Date()
  in_seconds = time.getTime()
  offset = time.getTimezoneOffset()
  utc_in_seconds = in_seconds + (offset * 60 * 1000)
  date_in_utc = new Date(utc_in_seconds)
  year = date_in_utc.getFullYear()
  month = date_in_utc.getMonth()
  date  = date_in_utc.getDate()
  hours = date_in_utc.getHours()
  minutes = date_in_utc.getMinutes()
  return new Date(Date.UTC(year, month, date, hours, minutes))

announce_new_user = (roomID) ->
  console.log("room ID is #{roomID}")
  message = Messages.insert
    name: "Server Message",
    roomID: roomID,
    message: "#{Session.get('name')} has entered the room on ",
    type: 'announcement',
    created: utc_time_stamp()
  console.log(message)

announce_departure = (roomID) ->
  Messages.insert
    name: "Server Message",
    roomID: roomID,
    message: "#{Session.get('name')} has left the room ",
    type: "announcement",
    created: utc_time_stamp()

all_rooms = ->
  rooms = Rooms.find({}, { sort: {time: -1}}).fetch()
  return rooms.slice(0,5).reverse()

has_provided_name = ->
  return Session.get("name")

is_in_room = ->
  return Session.get("roomID")

root = global ? window

if root.Meteor.is_client
  window.Messages = Messages
  window.Rooms = Rooms

  root.Template.hello.greeting = ->
    "Welcome to Chat with Rooms #{Session.get('name')||''}"

  Template.existing_rooms.rooms = ->
    return all_rooms()

  Template.room.scroll_to_bottom_of_chat_window = ->      
    Meteor.defer ->
      $("#chat").scrollTop 9999999
      $("#messageBox").focus()

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
          created: utc_time_stamp()
        Session.set("roomID", room)
        announce_new_user(room)
      return false

    'click #leave_room': (event) ->
      event.preventDefault()
      announce_departure(Session.get("roomID"))
      Session.set("roomID", "")

  Template.room_link.events =
    'click .room_link': (event) ->
      event.preventDefault()
      Session.set("roomID", $(this).attr("_id"))
      announce_new_user($(this).attr("_id"))
      $("#chat").scrollTop 9999999;
      return false

  Template.room.room_name = ->
    room = Rooms.findOne(Session.get('roomID'))
    return room.name

  Template.room.has_provided_name = ->
    return has_provided_name()

  Template.room.is_in_room = ->
    return is_in_room();

    # Load all documents in messages collection from Mongo
  Template.messages.messages = -> 
    roomID = Session.get("roomID")
    Messages.find({'roomID': roomID}, { sort: {time: -1} })

  Template.message.local_timestamp = (message) ->
    return local_time_stamp(this.created)

  Template.message.message_is_announcement = (message) ->
    return this.type == "announcement"

  # Listen for the following events on the entry template
  Template.entry.events =
    # All keyup events from the #messageBox element
    'keyup #messageBox': (event) ->
      if event.type == "keyup" && event.which == 13 # [ENTER]
        new_message = $("#messageBox")
        # Save values into Mongo

        Messages.insert
          name: Session.get('name'),
          roomID: Session.get("roomID"),
          message: new_message.val(),
          type: "speech",
          created: utc_time_stamp()

        # Clear the input boxes
        new_message.val("")
        new_message.focus()

        # Make sure new chat messages are visible
        $("#chat").scrollTop 9999999;

  Template.name_prompt.events =
    'submit': (event) ->
      event.preventDefault()
      name = $("#enter_name").val()
      if name == ""
        $("#name_errors").html("Seriously, I need a name")
      else
        $("#name_errors").html("")
        Session.set("name", name)
      return false

Meteor.startup ->
  