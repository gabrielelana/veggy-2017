var websocket
var heartbeat
var username = 'gabriele'

$(document).ready(function() {
  $('#server').val("ws://" + window.location.host + "/ws")
  if (!("WebSocket" in window)) {
    $('#status').append('<p><span style="color: red;">websockets are not supported </span></p>')
    $("#navigation").hide()
  } else {
    $('#status').append('<p><span style="color: green;">websockets are supported </span></p>')
    connect()
  }
  $("#connected").hide()
  $("#content").hide()
})

function connect() {
  wsHost = $("#server").val()
  websocket = new WebSocket(wsHost)
  showScreen('<b>Connecting to: ' +  wsHost + '</b>')
  websocket.onopen = function(evt) { onOpen(evt); }
  websocket.onclose = function(evt) { onClose(evt); }
  websocket.onmessage = function(evt) { onMessage(evt); }
  websocket.onerror = function(evt) { onError(evt); }
}

function disconnect() {
  websocket.close()
}

function toggle_connection() {
  if (websocket.readyState == websocket.OPEN) {
    disconnect()
  } else {
    connect()
  }
}

function sendTxt() {
  if (websocket.readyState == websocket.OPEN) {
    var txt = $("#send_txt").val()
    websocket.send(txt)
    showScreen('sending: ' + txt)
  } else {
    showScreen('websocket is not connected')
  }
}

function onOpen(evt) {
  showScreen('<span style="color: green;">CONNECTED </span><span id="ping-counter">0</span>')
  $("#connected").fadeIn('slow')
  $("#content").fadeIn('slow')
  websocket.send('login:' + username)
  heartbeat = setInterval(function() {
    if (websocket.readyState == websocket.OPEN) {
      websocket.send("ping")
    }
  }, 1000)
}

function onClose(evt) {
  clearInterval(heartbeat)
  showScreen('<span style="color: red;">DISCONNECTED </span>')
}

function onMessage(evt) {
  var data = JSON.parse(evt.data)
  if (data.event) {
    showScreen('<span style="color: blue;">' + data.event + ': ' + evt.data + '</span>')
  } else {
    if (data.message === "pong") {
      $("#ping-counter").text(parseInt($("#ping-counter").text(), 10) + 1)
    }
    console.log(evt.data)
  }
}

function onError(evt) {
  showScreen('<span style="color: red;">ERROR: ' + evt.data+ '</span>')
}

function showScreen(txt) {
  $('#output').prepend('<p>' + txt + '</p>')
}
