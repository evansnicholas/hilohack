#include <AccelStepper.h>

#define HILO_SERIAL_BAUDRATE 115200

#define PIN_LED               13  // Arduino on-board LED

#define PIN_DRAFTING_STEP     54  // Drafting Motor Step Pin
#define PIN_DRAFTING_DIR      55  // Drafting Motor Direction Pin
#define PIN_DRAFTING_ENABLE   38  // Drafting Motor Enable Pin

#define PIN_DELIVERY_STEP     60  // Delivery Motor Step Pin
#define PIN_DELIVERY_DIR      61  // Delivery Motor Direction Pin
#define PIN_DELIVERY_ENABLE   56  // Delivery Motor Enable Pin

#define PIN_SPINDLE_STEP      46  // Spindle Motor Step Pin
#define PIN_SPINDLE_DIR       48  // Spindle Motor Direction Pin
#define PIN_SPINDLE_ENABLE    62  // Spindle Motor Enable Pin

#define PIN_ELEVATOR_A_STEP   26  // Elevator Motors Step Pin
#define PIN_ELEVATOR_A_DIR    28  // Elevator Motors Direction Pin
#define PIN_ELEVATOR_A_ENABLE 24  // Elevator Motors Enable Pin

int DRAFTING_SPEED_PERCENTAGE = 40;
int DELIVERY_SPEED            = 280;
int SPINDLE_SPEED             = 700;
int ELEVATOR_SPEED            =  0;

float ACCELERATION = 500.00f;

bool IS_RUNNING = false;

AccelStepper motorDrafting(AccelStepper::DRIVER, PIN_DRAFTING_STEP, PIN_DRAFTING_DIR);
AccelStepper motorDelivery(AccelStepper::DRIVER, PIN_DELIVERY_STEP, PIN_DELIVERY_DIR);
AccelStepper motorElevatorA(AccelStepper::DRIVER, PIN_ELEVATOR_A_STEP, PIN_ELEVATOR_A_DIR);
AccelStepper motorSpindle  (AccelStepper::DRIVER, PIN_SPINDLE_STEP,    PIN_SPINDLE_DIR);

void setup() {
  Serial.begin(HILO_SERIAL_BAUDRATE);
  
  Serial.println("Starting HILO Machine");
  
  // put your setup code here, to run once:
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);
  
  // set the mode for the stepper driver enable pins
  pinMode (PIN_DRAFTING_ENABLE,   OUTPUT);
  pinMode (PIN_DELIVERY_ENABLE,   OUTPUT);
  pinMode (PIN_ELEVATOR_A_ENABLE, OUTPUT);
  pinMode (PIN_SPINDLE_ENABLE,    OUTPUT);

  setSteppersEnabled(false);
}

void loop() {
  // put your main code here, to run repeatedly:
  serialCommunicationLoop();
  runMachineLoop();
}

void serialCommunicationLoop() {
  if (Serial.available() > 0) {
    // read a character from serial, if one is available
    String data = Serial.readStringUntil('\n');
    Serial.print("Received ");
    Serial.println(data);
    if (data == " ") {
      startStopMachine();
    }
    if (data.startsWith("s")) {
      int spindleSpeed = data.substring(1).toInt();
      SPINDLE_SPEED = spindleSpeed;
      Serial.print("Spindle speed set to: ");
      Serial.println(SPINDLE_SPEED);
    }
    if (data.startsWith("d")) {
      int deliverySpeed = data.substring(1).toInt();
      DELIVERY_SPEED = deliverySpeed;
      Serial.print("Delivery speed set to: ");
      Serial.println(DELIVERY_SPEED);
    }
    if (data.startsWith("p")) {
      int draftingPercentage = data.substring(1).toInt();
      DRAFTING_SPEED_PERCENTAGE = draftingPercentage;
      Serial.print("Drafting percentage set to: ");
      Serial.println(DRAFTING_SPEED_PERCENTAGE);
    }
  }
}

void startStopMachine() {
  if (IS_RUNNING) {
    stopMachine();
  } else {
    startMachine();
  }
}

void stopMachine() {
  Serial.println("Stopping machine");
  IS_RUNNING = false;
  motorDrafting.stop();
  motorDrafting.setCurrentPosition(0);
  motorDelivery.stop();
  motorDelivery.setCurrentPosition(0);
  motorSpindle.stop();
  motorSpindle.setCurrentPosition(0);
  setSteppersEnabled(false);
}

void startMachine() {
  Serial.println("Starting machine");
  
  int draftingSpeed = (int)map(DRAFTING_SPEED_PERCENTAGE, 0, 100, 0, DELIVERY_SPEED);
  motorDrafting.setMaxSpeed(draftingSpeed);
  motorDrafting.setAcceleration(ACCELERATION);
  Serial.print("Drafting percentage: ");
  Serial.println(DRAFTING_SPEED_PERCENTAGE);
  Serial.print("Drafting speed: ");
  Serial.println(draftingSpeed);


  motorDelivery.setMaxSpeed(DELIVERY_SPEED);
  motorDelivery.setAcceleration(ACCELERATION);
  Serial.print("Delivery speed: ");
  Serial.println(DELIVERY_SPEED);

  // Don't move the elevator for now
  
  motorSpindle.setMaxSpeed(SPINDLE_SPEED);
  motorSpindle.setAcceleration(ACCELERATION);
  Serial.print("Spindle speed: ");
  Serial.println(SPINDLE_SPEED);

  motorDrafting.move(-1000000);
  motorDelivery.move(-1000000);
  motorSpindle.move(1000000);
  
  IS_RUNNING = true;
  setSteppersEnabled(true);
}

void runMachineLoop() {
  if (IS_RUNNING) {
      motorDrafting.run();
      motorDelivery.run();
      motorSpindle.run();
  }
}

// Enables or disables all steppers. Used for saving power
// and allowing adjustments by hand when the machine isn't running.
void setSteppersEnabled(bool enabled) {
  int value = LOW;
  if (!enabled) value = HIGH;

  digitalWrite(PIN_DRAFTING_ENABLE,   value);
  digitalWrite(PIN_DELIVERY_ENABLE,   value);
  digitalWrite(PIN_ELEVATOR_A_ENABLE, value);
  digitalWrite(PIN_SPINDLE_ENABLE,    value);
}
