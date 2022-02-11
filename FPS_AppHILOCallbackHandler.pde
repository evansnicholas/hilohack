// An object that handles callbacks from a HILO object (machine or simulator).
// A callback handler object is passed to a newly-created HILO object - see connectHILO() above.
// The callback handler implements methods from the HILOCallbackHandler as a way to be notified of changes in the
// HILO machine/simulator's status, and act accordingly.
class AppHILOCallbackHandler implements HILOCallbackHandler {

  // Called when HILO is connected (i.e. the serial port is open)
  void onHILOConnected() {
    debugMessage("onHILOConnected()");
    debugMessage("Connected on " + selectedPort);
    uploadHILOConfig();
  }

  // Called when HILO is disconnected.
  void onHILODisconnected() {
    debugMessage("onHILODisconnected()");
  }

  // Called when HILO starts spinning.
  void onStartSpinning() {
    debugMessage("onStartSpinning()");
  }

  // Called when HILO stops spinning.
  void onStopSpinning() {
    debugMessage("onStopSpinning()");
  }
  
}
