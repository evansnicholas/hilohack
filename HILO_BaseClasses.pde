// HILO - Base Classes
// This tab contains the base classes and interface for 
// an abstract HILO device and callback handler.


// Defines a common interface for HILO devices.
// It abstracts the device so we can use an actual machine, a simulator or (futurely) even a networked machine or cluster.
interface HILOInterface {
  
  // Assign a HILOCallbackHandler object to receive status updates from the device.
  void setCallbackHandler(HILOCallbackHandler callbackHandler);
  
  // Connect to the HILO device using the specified serial port.
  boolean connect(String portName);
  
  // Disconnect from the HILO device.
  boolean disconnect();
  
  // Returns true when the device is connected.
  boolean isConnected();
  
  // Returns true when the device is spinning.
  boolean isSpinning();
  
  // Returns true when the device has an unhandled error.
  boolean hasError();

  // Returns the name of the port on which the device is connected.
  String  getPortName();
  
  // Returns the state of the device (see the class HILOStatus).
  int     getState();
  
  // Returns the current delivery speed (in steps/second).
  int     getDeliverySpeed();
  
  // Returns the current spindle speed (in steps/second).
  int     getSpindleSpeed();
  
  // Returns the current elevator speed (in steps/second).
  int     getElevatorSpeed();
  
  // Sets the delivery speed to a specified value (in steps/second).
  boolean setDeliverySpeed(int speed);
  
  // Sets the spindle speed to a specified value (in steps/second).
  boolean setSpindleSpeed(int speed);
  
  // Sets the elevator speed to a specified value (in steps/second).
  boolean setElevatorSpeed(int speed);
 
  // Run the HILO device at the specified drafting speed (a percentage 0-100 of the current delivery speed).
  boolean spin(int draftingSpeedPerc);
  
  // Stop the device.
  boolean stop();  
}


// Defines a common interface for HILO callback handlers.
// In order to receive status updates from the HILO machine the application should 
// implement this interface (or provide an object which does so)
interface HILOCallbackHandler {
  
  // Called when HILO is connected (i.e. the serial port is open)
  void onHILOConnected();
  
  // Called when HILO is disconnected.
  void onHILODisconnected();
  
  // Called when HILO starts spinning.
  void onStartSpinning();
  
  // Called when HILO stops spinning.
  void onStopSpinning();
}


// Base object for the state of a HILO device
class HILOStatus {
  // Possible state codes of a HILO device
  final static int DISCONNECTED = 0;
  final static int CONNECTING   = 1;
  final static int READY        = 2;
  final static int SPINNING     = 3;
  final static int ERROR        = 4;
  
  protected int state;         // The current state (one of the above)
  protected int spindleSpeed;  // The current spindle speed (in steps/second)
  protected int draftingSpeed; // The current drafting speed (in steps/second)
  protected int elevatorSpeed; // The current elevator speed (in steps/second)
  protected int deliverySpeed; // The current delivery speed (in steps/second)
}
