var term;
var buf = '';
var socket;

function connect(userPrompt) {
  var protocol = (location.protocol === 'https:') ? 'wss://' : 'ws://';

  // hide the connect button
  document.getElementById("overlay").style.display = "none";

  if(socket) {
    socket.onclose = null;
    socket.close();
  }

  if(userPrompt && location.pathname == '/') {
    var username = prompt('What username would you like to connect with?');
    socket = new WebSocket(protocol + location.host + '/' + username + location.search);
  }
  else {
    socket = new WebSocket(protocol + location.host + location.pathname + location.search);
  }

  socket.onopen    = function()  { connected();            };
  socket.onclose   = function()  { disconnected();         }
  socket.onmessage = function(m) { messageHandler(m.data); };
}

function connected() {
  console.log('Client connected');
  lib.init(function() {
      hterm.defaultStorage = new lib.Storage.Local();
      term = new hterm.Terminal();
      window.term = term;
      term.decorate(document.getElementById('terminal'));

      term.setCursorPosition(0, 0);
      term.setCursorVisible(true);
      term.prefs_.set('ctrl-c-copy', true);
      term.prefs_.set('ctrl-v-paste', true);
      term.prefs_.set('use-default-window-copy', true);

      term.runCommandClass(Abalone, document.location.hash.substr(1));
      socket.send(JSON.stringify({
        event: 'resize',
        col: term.screenSize.width,
        row: term.screenSize.height
      }));

      if (buf && buf != '')
      {
          term.io.writeUTF16(buf);
          buf = '';
      }
  });

  /* save our terminal state on the server periodically, just in case we restart a session */
  // TODO: should we patch hterm to do this only when modes are set?
  setInterval(function() {
    socket.send(JSON.stringify({
      event: 'modes',
       data: getModes()
    }));
  }, 5000);

}

function disconnected() {
  console.log('Client disconnected');
  document.getElementById("overlay").style.display = "block";
}

function messageHandler(message) {
  var message = JSON.parse(message);
  var event = message['event'];
  var data  = message['data'];

  switch(event) {
    case 'time':
      document.getElementById("timer").style.display = "block";
      document.getElementById("timer").innerHTML = data;
      break;

    case 'modes':
      setModes(data);

    default:
      if (!term) {
          buf += data;
          return;
      }
      term.io.writeUTF16(data);
  }
}

function getModes() {
  return {
    "cursorBlink"       : term.vt.terminal.options_.cursorBlink,
    "cursorVisible"     : term.vt.terminal.options_.cursorVisible,
    "bracketedPaste"    : term.vt.terminal.options_.bracketedPaste,
    "applicationCursor" : term.vt.terminal.keyboard.applicationCursor
  };
}

function setModes(modes) {
  term.vt.terminal.options_.cursorBlink       = modes["cursorBlink"];
  term.vt.terminal.options_.cursorVisible     = modes["cursorVisible"];
  term.vt.terminal.options_.bracketedPaste    = modes["bracketedPaste"];
  term.vt.terminal.keyboard.applicationCursor = modes["applicationCursor"];
}

/* borrowed from https://github.com/krishnasrinivas/wetty */
function Abalone(argv) {
  this.argv_ = argv;
  this.io = null;
  this.pid_ = -1;
}

Abalone.prototype.run = function() {
  this.io = this.argv_.io.push();

  this.io.onVTKeystroke = this.sendString_.bind(this);
  this.io.sendString = this.sendString_.bind(this);
  this.io.onTerminalResize = this.onTerminalResize.bind(this);
}

Abalone.prototype.sendString_ = function(str) {
  socket.send(JSON.stringify({ event: 'input', data: str}));
};

Abalone.prototype.onTerminalResize = function(col, row) {
  socket.send(JSON.stringify({ event: 'resize', col: col, row: row}));
};

