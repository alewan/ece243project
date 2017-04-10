//have to do small tests to test this
int threshold = 100;
int outPin = 7;

void setup() {
  // put your setup code here, to run once:
  pinMode(outPin, OUTPUT);
  Serial.begin(9600);
}

void loop() {
  // put your main code here, to run repeatedly:
  if(analogRead(0) > threshold)
    digitalWrite(outPin, HIGH);
  else
    digitalWrite(outPin, LOW);
}
