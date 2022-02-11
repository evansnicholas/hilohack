// HILO - Simulator
// This tab contains the class for a HILO simulator.
// The simulator allows using the app without an actual machine. It is helpful in testing and showcasing.

import java.util.Timer;
import java.util.TimerTask;

// Class for a HILO simulator, helpful in testing and showcasing.
// A HILOSimulator object conforms to the HILOInterface, and it can be used instead of a HILODevice.
// It behaves like an actual device; likewise, it notifies the main app of changes 
// in the device's state through a HILOCallbackHandler object.
class HILOSimulator extends HILOStatus implements HILOInterface {
  
  // unique name for the simulator (to be displayed instead of an actual port name)
  final static String SIMULATOR_PORT_NAME = "Simulator";
  
  // object that handles HILO state changes, passed by the app
  protected HILOCallbackHandler callbackHandler;
  
  // timer used to trigger the onHILOConnected() and onHILODisconnected() callbacks
  protected Timer timerConnect;
  
  
  // Constructor, to which a callback handler is passed, 
  // used by the simulator to notifiy the app of state changes.
  HILOSimulator(HILOCallbackHandler callbackHandler) {
    this.callbackHandler = callbackHandler;
  }
  
  
  // Assign a callback handler, used to notifiy the app of changes in the simulator's state.
  void setCallbackHandler(HILOCallbackHandler callbackHandler) {
    this.callbackHandler = callbackHandler;
  }
  
  
  // == HILO INTERFACE =========================================================
  
  
  // HILOInterface: Connect to the HILO simulator.
  // Since this is a simulator, the portName parameter is actually ignored.
  boolean connect(String portName) {
    switch (state) {
      case HILOStatus.DISCONNECTED:
        state = HILOStatus.CONNECTING;
 
        // cancel any existing timer and create a new one to call onHILOConnected() after 1.5 secs
        if (timerConnect != null) {
          debugMessage("HILOSimulator.connect() WARNING: cancelling existing connect timer");
          timerConnect.cancel();
          timerConnect.purge();
        }
        timerConnect = new Timer();
        timerConnect.schedule(new TimerTask() {
          @Override
          public void run() {
            state = HILOStatus.READY;
            callbackHandler.onHILOConnected();
          }
        }, 1500);
        
        return true;
      
      case HILOStatus.CONNECTING:
        return true;
      case HILOStatus.ERROR:
        return false;
      default:
        return true; 
    }
  }
  
  
  // HILOInterface: Disconnect from the HILO device.
  boolean disconnect() {
    if (state == HILOStatus.CONNECTING || state == HILOStatus.READY || state == HILOStatus.SPINNING) {
      // cancel an existing timer
      if (timerConnect != null) {
        debugMessage("HILOSimulator.disconnect() cancelling existing connect timer");
        timerConnect.cancel();
        timerConnect.purge();
        timerConnect = null;
       }
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
    return SIMULATOR_PORT_NAME;
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
    if (state != READY) {
      debugMessage("HILOSimulator.setDeliverySpeed(): can't change speed while disconnected or spinning");
      return false;
    }
  
    debugMessage("HILOSimulator.setDeliverySpeed(): setting delivery speed to " + speed);
    deliverySpeed = speed;
    return true; 
  }
  
  
  // HILOInterface: Sets the spindle speed to a specified value (in steps/second).
  boolean setSpindleSpeed(int speed) { 
    if (!isConnected()) {
      debugMessage("HILOSimulator.setSpindleSpeed(): can't change speed while disconnected");
      return false;
    }
  
    debugMessage("HILOSimulator.setSpindleSpeed(): setting spindle speed to " + speed);
    spindleSpeed = speed;
    return true;
  }
  
  
  // HILOInterface: Sets the elevator speed to a specified value (in steps/second).
  boolean setElevatorSpeed(int speed) {
    if (!isConnected()) {
      debugMessage("HILOSimulator.setElevatorSpeed(): can't change speed while disconnected");
      return false;
    }
    
    debugMessage("HILOSimulator.setElevatorSpeed(): setting elevator speed to " + speed);
    elevatorSpeed = speed;
    return true;
  }
  
  
  // HILOInterface: Run the HILO device at the specified drafting speed (a percentage 0-100 of the current delivery speed).
  boolean spin(int draftingSpeedPerc) {
    // check if the value is within bounds
    if (draftingSpeedPerc < 0 || draftingSpeedPerc > 100) {
      debugMessage("HILOSimulator.sendPixel() WARNING: percentage value " + draftingSpeedPerc + " is out of bounds, correcting");
      draftingSpeedPerc = constrain(draftingSpeedPerc, 0, 100);
    }
  
    state = HILOStatus.SPINNING;
    
    // create a timer to call onStartSpinning() after 30 msecs
    Timer t = new Timer();
    t.schedule(new TimerTask() {
      @Override
      public void run() {
        callbackHandler.onStartSpinning();
      }
    }, 30);

    return true;
  }
  
  // HILOInterface: Stop the device.
  boolean stop() {
    state = HILOStatus.READY;
    
    // create a timer to call onStartSpinning() after 30 msecs
    Timer t = new Timer();
    t.schedule(new TimerTask() {
      @Override
      public void run() {
        callbackHandler.onStopSpinning();
      }
    }, 30);

    return true;
  }

}
