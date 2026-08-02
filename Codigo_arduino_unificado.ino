// =============================================================
//   COCHE ARDUINO - Sketch unificado (motores + HuskyLens)
// =============================================================
// Bluetooth (HC-05/HC-06) por SoftwareSerial: TX->10, RX->11
// HuskyLens por I2C: SDA=A4, SCL=A5
//
// Protocolo Bluetooth (lineas terminadas en \n):
//
//   App -> Arduino:
//     X<int>Y<int>\n      Mover motores (arcade drive). Ej "X120Y-80"
//     T<id>:<n>\n         Aprender <n> fotos para el ID <id> (1..255)
//     R\n                 Borrar todo el aprendizaje del HuskyLens
//     M<n>\n              Cambiar algoritmo del HuskyLens (0..6)
//                         0=face 1=track 2=obj_recog 3=line 4=color
//                         5=tag 6=classification (default)
//
//   Arduino -> App:
//     S<id>\n             Senal detectada con ID. Solo cuando cambia.
//                         S0 = ya no se ve nada / fondo
// =============================================================

#include <SoftwareSerial.h>
#include "HUSKYLENS.h"
#include "Wire.h"

SoftwareSerial miBluetooth(10, 11); // RX, TX
HUSKYLENS huskylens;

// --- PINES MOTORES ---
const int ENA = 9;  const int IN1 = 7; const int IN2 = 6;  // Motor derecho
const int ENB = 3;  const int IN3 = 4; const int IN4 = 2;  // Motor izquierdo

// --- ESTADO HUSKYLENS ---
int ultimoIdEnviado = -1;
unsigned long ultimaLecturaCamara = 0;
const unsigned long INTERVALO_CAMARA_MS = 80;  // ~12 FPS, no satura el bus

// --- BUFFER LECTURA BLUETOOTH ---
String bufferEntrada = "";

void setup() {
  Serial.begin(9600);
  miBluetooth.begin(38400);
  miBluetooth.setTimeout(20);
  Wire.begin();

  pinMode(ENA, OUTPUT); pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(ENB, OUTPUT); pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pararMotores();

  // HuskyLens es opcional: si no responde no bloqueamos al coche
  unsigned long inicioConexion = millis();
  while (!huskylens.begin(Wire)) {
    Serial.println(F("HuskyLens no responde."));
    if (millis() - inicioConexion > 4000) {
      Serial.println(F("Continuamos sin camara."));
      break;
    }
    delay(500);
  }
  huskylens.writeAlgorithm(ALGORITHM_OBJECT_CLASSIFICATION);

  Serial.println(F("Robot listo."));
}

void loop() {
  leerBluetooth();
  leerCamara();
}

// =============================================================
//                 BLUETOOTH - LECTURA
// =============================================================

void leerBluetooth() {
  while (miBluetooth.available() > 0) {
    char c = (char)miBluetooth.read();
    if (c == '\n') {
      procesarLinea(bufferEntrada);
      bufferEntrada = "";
    } else if (c != '\r') {
      bufferEntrada += c;
      if (bufferEntrada.length() > 32) bufferEntrada = "";  // proteccion
    }
  }
}

void procesarLinea(const String& linea) {
  if (linea.length() == 0) return;
  char prefijo = linea.charAt(0);

  if (prefijo == 'X') {
    int indexY = linea.indexOf('Y');
    if (indexY > 0) {
      int ejeX = linea.substring(1, indexY).toInt();
      int ejeY = linea.substring(indexY + 1).toInt();
      conducir(ejeX, ejeY);
    }
  } else if (prefijo == 'T') {
    int sep = linea.indexOf(':');
    if (sep > 1) {
      int id = linea.substring(1, sep).toInt();
      int n  = linea.substring(sep + 1).toInt();
      entrenar(id, n);
    }
  } else if (prefijo == 'R') {
    huskylens.writeForget();
    ultimoIdEnviado = -1;
  } else if (prefijo == 'M') {
    int n = linea.substring(1).toInt();
    cambiarAlgoritmo(n);
  }
}

void cambiarAlgoritmo(int n) {
  switch (n) {
    case 0: huskylens.writeAlgorithm(ALGORITHM_FACE_RECOGNITION); break;
    case 1: huskylens.writeAlgorithm(ALGORITHM_OBJECT_TRACKING); break;
    case 2: huskylens.writeAlgorithm(ALGORITHM_OBJECT_RECOGNITION); break;
    case 3: huskylens.writeAlgorithm(ALGORITHM_LINE_TRACKING); break;
    case 4: huskylens.writeAlgorithm(ALGORITHM_COLOR_RECOGNITION); break;
    case 5: huskylens.writeAlgorithm(ALGORITHM_TAG_RECOGNITION); break;
    case 6: huskylens.writeAlgorithm(ALGORITHM_OBJECT_CLASSIFICATION); break;
    default: return;
  }
  ultimoIdEnviado = -1;
}

void entrenar(int id, int n) {
  if (id < 1 || id > 50) return;
  if (n < 1) n = 1;
  if (n > 20) n = 20;
  pararMotores();  // por seguridad, no nos movemos mientras se entrena
  for (int i = 0; i < n; i++) {
    huskylens.writeLearn(id);
    delay(150);
  }
}

// =============================================================
//                 HUSKYLENS - LECTURA
// =============================================================

void leerCamara() {
  unsigned long ahora = millis();
  if (ahora - ultimaLecturaCamara < INTERVALO_CAMARA_MS) return;
  ultimaLecturaCamara = ahora;

  int idActual = 0;  // 0 = nada visto
  if (huskylens.request() && huskylens.available()) {
    while (huskylens.available()) {
      HUSKYLENSResult result = huskylens.read();
      if (result.command == COMMAND_RETURN_BLOCK) {
        idActual = result.ID;
        break;  // primera deteccion basta
      }
    }
  }

  if (idActual != ultimoIdEnviado) {
    ultimoIdEnviado = idActual;
    miBluetooth.print('S');
    miBluetooth.print(idActual);
    miBluetooth.print('\n');
  }
}

// =============================================================
//                 CONTROL MOTORES (arcade)
// =============================================================

void conducir(int x, int y) {
  // Invertimos Y para que joystick adelante = coche adelante (motores
  // montados al reves en este chasis).
  y = -y;
  int velIzquierda = constrain(y + x, -255, 255);
  int velDerecha   = constrain(y - x, -255, 255);
  controlarMotorIzquierdo(velIzquierda);
  controlarMotorDerecho(velDerecha);
}

void controlarMotorIzquierdo(int velocidad) {
  if (velocidad > 0) {
    digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
    analogWrite(ENB, velocidad);
  } else if (velocidad < 0) {
    digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH);
    analogWrite(ENB, abs(velocidad));
  } else {
    digitalWrite(IN3, LOW); digitalWrite(IN4, LOW);
    analogWrite(ENB, 0);
  }
}

void controlarMotorDerecho(int velocidad) {
  if (velocidad > 0) {
    digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
    analogWrite(ENA, velocidad);
  } else if (velocidad < 0) {
    digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH);
    analogWrite(ENA, abs(velocidad));
  } else {
    digitalWrite(IN1, LOW); digitalWrite(IN2, LOW);
    analogWrite(ENA, 0);
  }
}

void pararMotores() {
  controlarMotorIzquierdo(0);
  controlarMotorDerecho(0);
}
