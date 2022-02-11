// HILO - Device
// This tab contains the classes for a HILO device, used to interface with a HILO machine over a serial port.

import processing.serial.*;

// Class for a HILO device, used to interface with a HILO machine over a serial port.
// A HILODevice object conforms to the HILOInterface, and notifies the main app of changes 
// in the machine's state through a HILOCallbackHandler object.
class HILODevice extends HILOStatus implements HILOInterface {
  
  // Following are definitions for the HILO communication protocol
  final static char CMD_NONE      = 0;
  // Delimiters
  final static char CMD_DELIM_BEGIN     = '[';
  final static char CMD_DELIM_END       = ']';
  final static char CMD_DELIM_PARAM     = ',';
  // Control/Info
  final static char CMD_PING            = 'A';
  final static char CMD_ERROR           = 'E';
  final static char CMD_DEBUG           = 'X';
  // Spin
  final static char CMD_RUN             = 'R';
  final static char CMD_STOP            = 'S';
  // Settings
  final static char CMD_DELIVERY_SPEED  = 'D';
  final static char CMD_SPINDLE_SPEED   = 'P';
  final static char CMD_ELEVATOR_SPEED  = 'L';
  
  // length of the incoming buffer, where bytes received from serial 
  // are stored until we have a full command to parse  
  final static int DEFAULT_COMMAND_BUFFER_LENGTH = 128;
  
  protected char [] commandBuffer;               // command buffer and current
  protected int     commandBufferPos = 0;        // writing index in the buffer (or amount of bytes received)

  protected ArrayList<HILOCommand> commandQueue; // queue for commands coming from the parent/app
  protected char currentCommand = CMD_NONE;      // command currently being executed 
  
  protected PApplet parent;                      // reference to the app (parent)
  protected Serial serial;                       // serial port object
  protected String portName = "";                // name of the serial port in use
  protected HILOCallbackHandler callbackHandler; // object that handles HILO state changes, passed by the app
  
  protected Thread threadHiloUpdate;             // thread for periodically updating the HILODevice object
  
  
  // Constructor, to which is passed a reference to the parent app and a callback handler, 
  // used by the HILODevice to notifiy the app of changes in the machine's state.
  HILODevice(PApplet parent, HILOCallbackHandler callbackHandler) {
    
    this.portName = "";
    this.parent = parent;
    this.callbackHandler = callbackHandler;
    this.commandBuffer = new char [DEFAULT_COMMAND_BUFFER_LENGTH];
    this.commandQueue = new ArrayList<HILOCommand>();
    
    // create and start the thread resposible for running the HILO device's logic,
    // i.e. processing the command queue and serial events
    threadHiloUpdate = new Thread() {
      @Override
      public void run() { 
        while(true) {
          if (state == HILOStatus.READY || state == HILOStatus.SPINNING) {
            processCommandQueue();
          }
          processSerialEvents();
          try {
            sleep(5);
          } catch (InterruptedException e) {
            debugMessage("threadHiloUpdate.run(): interrupted while sleeping ");
          }
        }
      }
    };
    threadHiloUpdate.start();
  }
  
  
  // Assign a callback handler, used by the HILODevice to notifiy the app of changes in the machine's state.
  void setCallbackHandler(HILOCallbackHandler callbackHandler) {
    this.callbackHandler = callbackHandler;
  }
  
  
  // == HILO INTERFACE =========================================================


  // HILOInterface: Connect to the HILO device using the specified serial port.
  boolean connect(String portName) {
    switch (state) {
      case HILOStatus.DISCONNECTED:
      
        this.portName = portName;
        state = HILOStatus.CONNECTING;
        debugMessage("HILODevice.connect(): connecting to HILO on serial port <" + portName + ">");
        
        try {
          serial = new Serial(parent, portName, 115200);
        } catch (RuntimeException rte) {
          state = HILOStatus.ERROR;
          debugMessage("HILODevice.connect() ERROR: serial port doesn't exist or is busy <" + portName + ">");
          return false;
        }
        if (!serial.active()) {
          state = HILOStatus.ERROR;
          debugMessage("HILODevice.connect() ERROR: can't connect to HILO on serial port <" + portName + ">");
          return false;
        }
  
        // on older computers the Java serial takes a bit of time to start
        // and we don't seem to have a reliable way to check if the port is ready
        // so this delay is a workaround 
        delay(2000);
        
        debugMessage("HILODevice.connect(): CONNECTED");
        state = HILOStatus.READY;
        
        // notify the handler that HILO is connected, using a separate thread
        Thread ta = new Thread() {
          @Override
          public void run() { 
            callbackHandler.onHILOConnected();
          }
        };
        ta.start();
  
        return true;
      
      case HILOStatus.CONNECTING:
        debugMessage("HILODevice.connect() WARNING: already connected on serial port <" + portName + ">");
        return true;
      case HILOStatus.ERROR:
        debugMessage("HILODevice.connect() WARNING: a previous error is still flagged; please call disconnect() to clear it");
        return false;
      default:
        return true;
    }
  }

  
  // HILOInterface: Disconnect from the HILO device.
  boolean disconnect() { 
    if (state == HILOStatus.DISCONNECTED) {
      debugMessage("HILODevice.disconnect() WARNING: device was already disconnected");
    } 
    else if (state == HILOStatus.ERROR) {
      debugMessage("HILODevice.disconnect(): clearing error status");
    }
    
   
    if (serial != null && serial.active()) {
      debugMessage("HILODevice.disconnect(): clearing command queue");
      commandQueue.clear();
      debugMessage("HILODevice.disconnect(): disposing of serial port connection");
      serial.dispose();
      serial = null;
    }

    state = HILOStatus.DISCONNECTED;
        
    // notify the handler that HILO is disconnected, using a separate thread
    Thread ta = new Thread() {
      @Override
      public void run() { 
        callbackHandler.onHILODisconnected();
      }
    };
    ta.start();
    

    return true;
  }
  
  
  // HILOInterface: Returns true when the device is connected.
  boolean isConnected() { 
    return (state == HILOStatus.READY || state == HILOStatus.SPINNING); 
  }  
  
  
  // HILOInterface: Returns true when the device is spinning.
  boolean isSpinning() { 
    return state == HILOStatus.SPINNING;
  }
  
  
  // HILOInterface: Returns true when the device has an unhandled error.
  boolean hasError() { 
    return state == HILOStatus.ERROR;
  }

  
  // HILOInterface: Returns the name of the port on which the device is connected.
  String getPortName() {
    return this.portName;
  }


  // HILOInterface: Returns the state of the device (see the class HILOStatus).
  int getState() { 
    return state; 
  }

  
  // HILOInterface: Returns the current delivery speed (in steps/second).
  int getDeliverySpeed()  { return deliverySpeed; }
  
  
  // HILOInterface: Returns the current spindle speed (in steps/second).
  int getSpindleSpeed()  { return spindleSpeed; }
  
  
  // HILOInterface: Returns the current elevator speed (in steps/second).
  int getElevatorSpeed()  { return elevatorSpeed; }
    
  
  // HILOInterface: Sets the delivery speed to a specified value (in steps/second).
  boolean setDeliverySpeed(int speed) { 
    if (!isConnected()) {
      println("HILODevice.setDeliverySpeed(): can't change speed while disconnected");
      return false;
    }
    
    // set the delivery speed locally and queue the command to update the actual machine
    debugMessage("HILODevice.setDeliverySpeed(): setting delivery speed to " + speed);
    deliverySpeed = speed;
    queueCommand(CMD_DELIVERY_SPEED, deliverySpeed);
    return true;
  }
  
  
  // HILOInterface: Sets the spindle speed to a specified value (in steps/second).
  boolean setSpindleSpeed(int speed) { 
    if (!isConnected()) {
      debugMessage("HILODevice.setSpindleSpeed(): can't change speed while disconnected");
      return false;
    }
    
    // set the spindle speed locally and queue the command to update the actual machine
    debugMessage("HILODevice.setSpindleSpeed(): setting spindle speed to " + speed);
    spindleSpeed = speed;
    queueCommand(CMD_SPINDLE_SPEED, spindleSpeed);
    return true;
  }
  
  
  // HILOInterface: Sets the elevator speed to a specified value (in steps/second).
  boolean setElevatorSpeed(int speed) {
    if (!isConnected()) {
      debugMessage("HILODevice.setElevatorSpeed(): can't change speed while disconnected");
      return false;
    }
    
    // set the elevator speed locally and queue the command to update the actual machine
    debugMessage("HILODevice.setElevatorSpeed(): setting elevator speed to " + speed);
    elevatorSpeed = speed;
    queueCommand(CMD_ELEVATOR_SPEED, elevatorSpeed);
    return true;
  }
  
  
  // HILOInterface: Run the HILO device at the specified drafting speed (a percentage 0-100 of the current delivery speed).
  boolean spin(int draftingSpeedPerc) {
    // check if the value is within bounds
    if (draftingSpeedPerc < 0 || draftingSpeedPerc > 100) {
      debugMessage("HILODevice.spin() WARNING: percentage value " + draftingSpeedPerc + " is out of bounds, correcting");
      draftingSpeedPerc = constrain(draftingSpeedPerc, 0, 100);
    }
    // queue the command to run the machine
    queueCommand(CMD_RUN, draftingSpeedPerc);
    return true;
  }
 
  
  // HILOInterface: Stop the device.
  boolean stop() {
    // queue the command to stop the machine
    queueCommand(CMD_STOP);
    return true;
  }
  
  
  // == INTERNAL LOGIC =========================================================
  
  
  // Queue a simple command for execution by the update thread.
  protected void queueCommand(char command) {
    debugMessage("HILODevice.queueCommand(): " + command);
    commandQueue.add(new HILOCommand(command));
  }
  
  
  // Queue a command and parameter/value for execution by the update thread.
  protected void queueCommand(char command, int value) {
    debugMessage("HILODevice.queueCommand(): " + command + " " + value);
    commandQueue.add(new HILOCommand(command, value));
  }
  
  
  // Queue a command and two parameters/values for execution by the update thread.
  protected void queueCommand(char command, int valueMin, int valueMax) {
    debugMessage("HILODevice.queueCommand(): " + command + " " + valueMin + " " + valueMax);
    commandQueue.add(new HILOCommand(command, valueMin, valueMax));
  }
  
  
  // Called by the update thread to run one iteration of the command queue,
  // i.e. retrieve and handle the next command. 
  protected void processCommandQueue() {
    // if there are no command ins the queue, or still handling a command, do nothing 
    if (commandQueue.isEmpty()) return;
    if (currentCommand != CMD_NONE) return;
    
    // retrieve a command
    HILOCommand command = commandQueue.get(0);
    commandQueue.remove(command);
    debugMessage("HILODevice.processCommandQueue(): processing command " + command.command);
    currentCommand = command.command;
   
    // compose the complete command string to be sent to the machine
    String strCommand = "" + CMD_DELIM_BEGIN + command.command;
    if (command.numParams > 0) 
      strCommand += "" + CMD_DELIM_PARAM + command.paramA;
    if (command.numParams > 1) 
      strCommand += "" + CMD_DELIM_PARAM + command.paramB;  
    strCommand += CMD_DELIM_END;
    
    // send the command to the machine
    debugMessage("HILODevice.processCommandQueue(): sending command " + strCommand);
    if (serial.active()) {
      serial.write(strCommand);
    }
    else {
      debugMessage("HILODevice.processCommandQueue() WARN: can't send command " + strCommand + " - serial port closed");
    }
    // the reply will be received as bytes, handled in processSerialEvents() below
  }
  
  
  // Called by the update thread to read incoming bytes from the machine's serial port.
  // As the closing delimiter is received, a complete message is parsed for command and parameters
  // and handled accordingly. 
  protected void processSerialEvents() {
    if (serial == null) return;
    
    // Keep reading while there are bytes being received
    while (serial.available() > 0) {
      // Read a character
      int val = serial.read();
      char valChar = (char)val;
      
      // ignore CR and LF
      if (val == 10 || val == 13) return;
      
      // clear the buffer of anything we may have received befor ethe start delimiter 
      if (valChar == CMD_DELIM_BEGIN) {
        commandBufferPos = 0;
      }
      
      // add the received character to our buffer
      commandBuffer[commandBufferPos++] = valChar;
      
      // this should never happen, but we have this guard here to prevent fatal crashes if it ever does
      if (commandBufferPos >= commandBuffer.length) {
        debugMessage("HILODevice.processSerialEvents() ERROR: command buffer is full, clearing");
        debugMessage("\tcommand buffer:");
        debugMessage("\t" + new String(commandBuffer));
        commandBufferPos = 0;
      }
      
      // we received the end delimiter, so we should have a complete mesage in the buffer;
      // we will parse and handle it depending on the command it contains
      if (valChar == CMD_DELIM_END) {
        String message = new String(commandBuffer, 0, commandBufferPos);
        commandBufferPos = 0;
        int command = parseHiloMessage(message);
        switch (command) {
          case CMD_PING:
            handleMessagePing();
            break;
          case CMD_RUN:
            handleMessageSpin();
            break;
          case CMD_STOP:
            handleMessageStop();
            break;
          case CMD_DELIVERY_SPEED:
          case CMD_SPINDLE_SPEED:
          case CMD_ELEVATOR_SPEED:
            handleMessageSettings(command);
            break;
          case CMD_DEBUG:
            handleMessageDebug(message);
            break;
          default:
            handleMessageError(command);
            break;
        }
      }
    }
  }
  
  
  // Handles a "ping" reply by printing debug info.
  protected void handleMessagePing() {
    if (state == HILOStatus.READY) {
      debugMessage("HILODevice.handleMessagePing(): received PING but HILO was already connected!");
    }
    else {
      debugMessage("HILODevice.handleMessagePing() WARNING: received PING but HILO state is [" + state + "]");
    }
  }
  
  
  // Handles a spin ("run") reply/confirmation. Notifies the handler using a separate thread.
  private void handleMessageSpin() {
    if (currentCommand != CMD_RUN) {
      debugMessage("HILODevice.handleMessageSpin() WARNING: received " + CMD_RUN + " but current command is " + currentCommand);
    }
    state = HILOStatus.SPINNING;
    
    currentCommand = CMD_NONE;
    Thread t = new Thread() {
      @Override
      public void run() { callbackHandler.onStartSpinning(); }
    };
    t.start();
  }
  
  
  // Handles a "stop" reply/confirmation. Notifies the handler using a separate thread.
  private void handleMessageStop() {
    if (currentCommand != CMD_STOP) {
      debugMessage("HILODevice.handleMessageStop() WARNING: received " + CMD_STOP + " but current command is " + currentCommand);
    }
    state = HILOStatus.READY;
    
    currentCommand = CMD_NONE;
    Thread t = new Thread() {
      @Override
      public void run() { 
        callbackHandler.onStopSpinning();
      }
    };
    t.start();
  }
  
  
  // Handles a reply/confirmation when machine settings are updated.
  private void handleMessageSettings(int command) {
    if (state == HILOStatus.SPINNING && command != CMD_SPINDLE_SPEED) {
      debugMessage("HILODevice.handleMessageSettings() WARNING: received " + command + " but current state is HILOStatus.SPINNING");
    }
    
    currentCommand = CMD_NONE;
    debugMessage("HILODevice.handleMessageSettings() confirmed " + (char)command);
  }
  
  
  // Handles a debug message sent from the machine.
  private void handleMessageDebug(String completeMessage) {
    debugMessage("HILODevice.handleMessageDebug() HILO DEBUG: " + completeMessage);
  }
  
  
  // Handles an error message sent by the machine.
  private void handleMessageError(int errorCode) {
    debugMessage("HILODevice.handleMessageError() WARNING: not implemented!");
  }
  
  
  // Parses a message sent by the HILO machine. Retrieves and returns the command/code in the message. 
  int parseHiloMessage(String message) {
    debugMessage("parseHiloMessage(): parsing message " + message);
    
    if (message.charAt(0) != CMD_DELIM_BEGIN) {
      debugMessage("parseHiloMessage() ERROR: message doesn't start with delimiter");
    }
    else if (message.charAt(message.length()-1) != CMD_DELIM_END) {
      debugMessage("parseHiloMessage() ERROR: message doesn't end with delimiter");
    }
    
    if (message.charAt(1) == CMD_ERROR) {
      // parse the error code and return it
      try {
        int startIndex = message.indexOf(""+CMD_DELIM_PARAM) + 1;
        String errorCodeString = message.substring(startIndex, message.length()-1); 
        int errorCode = Integer.parseInt(errorCodeString);
        debugMessage("parseHiloMessage() Error code: " + errorCode);
      } catch (NumberFormatException nfe) {
        debugMessage("parseHiloMessage() ERROR: couldn't parse error code from HILO device, message " + message);
        return CMD_ERROR;
      }
    }
    
    if (message.charAt(1) == CMD_DEBUG) {
      int startIndex = message.indexOf(""+CMD_DELIM_PARAM) + 1;
      String debugMessage = message.substring(startIndex, message.length()-1);
      debugMessage("parseHiloMessage() Debug Message: " + debugMessage);
    }
    
    return (int)message.charAt(1);
  }
  
  
  // Nested utility class to hold commands (and parameters) for a command queue.
  class HILOCommand {
    char command;
    int paramA;
    int paramB;
    int numParams = 0;
    
    HILOCommand(char command) {
      this.command = command;
    }
    
    HILOCommand(char command, int paramA) {
      this.command   = command;
      this.paramA    = paramA;
      this.numParams = 1;
    }
    
    HILOCommand(char command, int paramA, int paramB) {
      this.command   = command;
      this.paramA    = paramA;
      this.paramB    = paramB;
      this.numParams = 2;
    }
  }

}
