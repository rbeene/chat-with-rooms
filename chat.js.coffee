Messages = new Meteor.Collection "messages"
Rooms    = new Meteor.Collection "rooms"
Users     = new Meteor.Collection "users"
Participants = new Meteor.Collection "participants"

room = ->
  return Rooms.findOne(Session.get('roomID'))

get_participants_for_room = (roomID) ->
  return Participants.find({'active': true, 'roomID' : roomID}).fetch()

total_participants_for_room = (roomID) ->
  return get_participants_for_room(roomID).length

add_participant = (roomID) ->
  participantID = Participants.insert
    name: Session.get('name'),
    userID: Session.get('userID'),
    active: true,
    roomID: roomID
    created: utc_time_stamp()
  announce_new_user(roomID)
  Session.set("participantID", participantID)

remove_participant = ->
  Participants.update(Session.get('participantID'), {$set: {active: false}})
  announce_departure(Session.get('roomID'))
  return true

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
  message = Messages.insert
    name: "Server Message",
    roomID: roomID,
    message: "#{Session.get('name')} has entered the room on ",
    type: 'announcement',
    created: utc_time_stamp()

announce_departure = (roomID) ->
  Messages.insert
    name: "Server Message",
    roomID: roomID,
    message: "#{Session.get('name')} has left the room ",
    type: "announcement",
    created: utc_time_stamp()

all_rooms = ->
  rooms = Rooms.find({}, { sort: {time: 1}}).fetch()
  return rooms.slice(0,5)

has_provided_name = ->
  return Session.get("name")

is_in_room = ->
  return Session.get("roomID")

root = global ? window

if root.Meteor.is_client
  window.Messages     = Messages
  window.Rooms        = Rooms
  window.Participants = Participants
  window.Users        = Users
  
  root.Template.hello.greeting = ->
    "Welcome to Chat with Rooms #{Session.get('name')||''}"

  Template.existing_rooms.rooms = ->
    return all_rooms()

  Template.in_room.scroll_to_bottom_of_chat_window = ->      
    Meteor.defer ->
      $("#chat").scrollTop 9999999
      $("#messageBox").focus()

  Template.room.events =
    'submit #room_form': (event) ->
      event.preventDefault()
      room_name = $("#create_room_name").val()
      if room_name == ""
        $("#create_room_errors").html("Type in a name buddy")
      else
        $("#create_room_errors").html("")
        roomID = Rooms.insert
          name: room_name
          created: utc_time_stamp()
        Session.set("roomID", roomID)
        add_participant(roomID)
        announce_new_user(room)
      return false

    'click #leave_room': (event) ->
      event.preventDefault()
      remove_participant()
      Session.set("roomID", "")

  Template.room_link.events =
    'click .room_link': (event) ->
      event.preventDefault()
      roomID = $(this).attr("_id")
      Session.set("roomID", roomID)
      add_participant(roomID)
      $("#chat").scrollTop 9999999;
      return false

  Template.room_link.participant_count = (room) ->
    return total_participants_for_room(this._id)

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
    messages = Messages.find({'roomID': roomID}, { sort: {time: -1} })
    messages.observe({
      added: -> 
        $("#chat").scrollTop 99999999;
    })
    return messages

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

  Template.messages.total_participants_for_room = ->
    total_participants_for_room(Session.get('roomID'))

  Template.messages.participants = ->
    get_participants_for_room(Session.get('roomID'))

  Template.name_prompt.events =
    'submit': (event) ->
      event.preventDefault()
      name = $("#enter_name").val()
      if name == ""
        $("#name_errors").html("Seriously, I need a name")
      else
        $("#name_errors").html("")
        userID = Users.insert
          name: name,
          created: utc_time_stamp()
        Session.set("userID", userID)
        Session.set("name", name)
      return false

Meteor.startup ->
