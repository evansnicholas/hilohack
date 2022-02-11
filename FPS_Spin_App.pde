void debugMessage(String message) {
  println(message);
}

AppHILOCallbackHandler appHILOCallbackHandler = new AppHILOCallbackHandler();

 HILOInterface hilo = new HILODevice(this, appHILOCallbackHandler);
//HILOInterface hilo = new HILOSimulator(appHILOCallbackHandler);

String [] portList;
String selectedPort;

// Spinning values
// HILO defaults: min 20 max 80
int draftingSpeedPerc = 20;
//HILO defaults: min 200 max 700
int spindleSpeedSteps = 400;
// HILO default: 300
int deliverySpeedSteps = 300;

void setup() {
  println("Setting up");

  portList = Serial.list();
  int index = 0;
  for (String port : portList) {
    println(index + " " + port);
    index++;
  }
}


// Called by Processing to draw a new frame; updates and draws the UI
void draw() {
}

void startSpinning() {
   hilo.connect(selectedPort);
}

// Upload configuration parameters to the machine
void uploadHILOConfig() {
  hilo.setDeliverySpeed(deliverySpeedSteps);
  hilo.setSpindleSpeed(spindleSpeedSteps);
}

// Called by Processing when a key is pressed
void keyPressed() {
  if ((int)key >= 48 && (int)key <= 56) {
    int selectedIndex = (int)key - 48;
    if (selectedIndex < portList.length) {
      selectedPort = portList[selectedIndex];
      debugMessage("Using port:" + selectedPort);
    } else {
      debugMessage("Unknown port");  
    }
  }
  
  switch (key) {
  case 'c':
    thread("connectHILO");
    break;
  case '\n':
    startSpinning();
    break;
  case ' ':
    if (hilo.isSpinning()) {
      debugMessage("Spinning stopped.");
      hilo.stop();
    } else {
      debugMessage("Starting to spin...");
      debugMessage("Drafting speed percentage: " + draftingSpeedPerc);
      hilo.spin(draftingSpeedPerc);
    }
    break;
  default:
    debugMessage("key " + (int)key + " [" + (char)key + "]");
    break;
  }
}
