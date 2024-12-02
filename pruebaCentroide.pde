// ---- Librerías ----
import gab.opencv.*;
import processing.core.*;
import processing.video.*;
import fisica.*;
import processing.sound.*;

// ---- Variables globales ----
boolean pruebaCamara = false;
PImage img;
OpenCV opencv;
FWorld world;
ArrayList<FCircle> balls;
FPoly poly;
Capture camara;

SoundFile abucheo, risas, tomatazo;

AudioIn micDialogo, micAplauso;
Amplitude ampDialogo, ampAplauso;

float AMP_MIN_Dialogo = 0.05; //0.05
float AMP_MAX_Dialogo = 0.150; //0.150

float AMP_MIN_Aplauso = 0.05; //0.05
float AMP_MAX_Aplauso = 0.150; //0.150

GestorSenial gestorAmpDialogo;
GestorSenial gestorAmpAplauso;

boolean monitorear = false;

boolean antesHabiaSonido;

float DIALOGO_UMBRAL = 0.05; //0.05
float DIALOGO_DURACION = 3000; //3000

float APLAUSO_UMBRAL = 0.15; //0.15
int APLAUSO_COOLDOWN = 0; //300

boolean hayDialogo = false;
boolean hayAplauso = false;

int dialogoInicio;
int aplausoUltimoTiempo;

FCircle ondaExpansiva;
int ancho = 640;
int alto = 480;
int umbral = 120; //40 en lo de Joaco
float fillProgress = 0;
boolean isFilledRed = false;
int redOpacity = 20;

float centroidX = 0;
float centroidY = 0;
float interpolatedX = 0;
float interpolatedY = 0;
float smoothFactor = 0.1; // Factor de suavizado (0.0 - sin cambio, 1.0 - salto inmediato) Valores bajos (e.g., 0.05): Movimiento más suave, pero más lento. Valores altos (e.g., 0.5):

// Variables para la animación
PImage[] frames; // Almacenará las imágenes PNG
int frameCount = 120; // Número de imágenes en la secuencia
int lastTomateTime = 0;

// variables tomates
ArrayList<TomateAnimado> tomates;

// ---- Configuración inicial ----
void setup() {
  size(640, 480);

  iniciarSeniales();
  iniciarMic2();
  iniciarMic1();
  iniciarFisica();
  iniciarCamara();
  iniciarOpenCV();
  iniciarOndaExpansiva();
  tomates = new ArrayList<TomateAnimado>();
  frames = new PImage[frameCount];
  for (int i = 0; i < frameCount; i++) {
    String filename = "data/frame" + nf(i + 1, 4) + ".png"; // Nombra los archivos correctamente
    frames[i] = loadImage(filename);
  }
}

// ---- Bucle principal ----
void draw() {
  background(0);
  
  hayDialogo = gestorAmpDialogo.filtrada > AMP_MIN_Dialogo;

  boolean inicioElSonido = hayDialogo && !antesHabiaSonido;
  boolean finDelSonido = !hayDialogo && antesHabiaSonido;

  if (inicioElSonido) println("Inicio de sonido detectado");
  //if (finDelSonido) println("Fin de sonido detectado");

  detectarDialogo();
  detectarAplauso();
  monitorearSenales();
  procesarCamara();
  actualizarFisica();
  ajustarOndaExpansiva();
  dibujarOndaExpansiva();
  crearPelotitas();
}

// ---- Inicializaciones ----
void iniciarSeniales() {
   gestorAmpDialogo = new GestorSenial(AMP_MIN_Dialogo, AMP_MAX_Dialogo);
  gestorAmpAplauso = new GestorSenial(AMP_MIN_Aplauso, AMP_MAX_Aplauso);
}

void iniciarMic1() {
  // Configurar entradas de audio
  micDialogo = new AudioIn(this, 0); // Primer micrófono
  micDialogo.start();


  // Amplitud para detectar niveles de audio
  ampDialogo = new Amplitude(this);
  ampDialogo.input(micDialogo);


}
void iniciarMic2() {
  // Configurar entradas de audio
 
  micAplauso = new AudioIn(this, 1); // Segundo micrófono
  micAplauso.start();

  // Amplitud para detectar niveles de audio
  ampAplauso = new Amplitude(this);
  ampAplauso.input(micAplauso);

  // Cargar archivos de audio
  abucheo = new SoundFile(this, "data/abucheo.mp3");
  risas = new SoundFile(this, "data/risas.mp3");
  tomatazo = new SoundFile(this, "data/tomatazo.mp3");
}

void iniciarFisica() {
  Fisica.init(this);
  world = new FWorld();
  world.setGravity(0, 300);
  balls = new ArrayList<FCircle>();
}

void iniciarCamara() {
  String[] listaDeCamaras = Capture.list();
  if (listaDeCamaras.length == 1) {
    println("No se encontraron cámaras.");
    exit();
  } else {
    camara = new Capture(this, listaDeCamaras[0]);
    camara.start();
  }
}

void iniciarOpenCV() {
  opencv = new OpenCV(this, ancho, alto);
  opencv.findContours();
}

void iniciarOndaExpansiva() {
  ondaExpansiva = new FCircle(0);
  ondaExpansiva.setStroke(0);
  ondaExpansiva.setFill(0, 255, 0);
  ondaExpansiva.setStrokeColor(color(0,255,0));
  ondaExpansiva.setPosition(width / 2, height / 2);
  ondaExpansiva.setStatic(true);
  world.add(ondaExpansiva);
}

// ---- Funciones de procesamiento ----
void detectarDialogo() {
  float nivel = ampDialogo.analyze(); // Analiza la amplitud del micrófono
  
  if (nivel > DIALOGO_UMBRAL) { // Si supera el umbral
 // println("dialogo detectado: nivel = "+ nivel);
    if (!hayDialogo) { // Si no hay diálogo previo detectado
      dialogoInicio = millis(); // Registra el inicio del diálogo
      hayDialogo = true;
    }
  } else if (hayDialogo && (millis() - dialogoInicio >= DIALOGO_DURACION)) {
    println("Hay diálogo"); // Acción cuando se detecta un diálogo válido
; // Rebobina el sonido de abucheo
    abucheo.play(); // Reproduce el sonido
    crearPelotitas(); // Llama a la función para crear una bola (o el equivalente)
    hayDialogo = false; // Resetea el estado del diálogo
  }
}


void detectarAplauso() {
  float nivel = ampAplauso.analyze();
  if (nivel > APLAUSO_UMBRAL) {
    println("Aplauso detectado: nivel = " + nivel);
  }
}

void monitorearSenales() {
  float vol = ampDialogo.analyze();
  gestorAmpDialogo.actualizar(vol);
  gestorAmpAplauso.actualizar(vol);

  if (monitorear) {
    gestorAmpDialogo.dibujar(25, 25);
    gestorAmpAplauso.dibujar(225, 25);
  }

  antesHabiaSonido = hayDialogo;
}

void procesarCamara() {
  if (camara.available()) {
    camara.read();
    opencv.loadImage(camara);
    opencv.threshold(umbral);
    //opencv.invert();
  }
}

void actualizarFisica() {
  world.step();
  world.draw();
  findAndSimplifyLargestPolygon();
}

void ajustarOndaExpansiva() {
  float vol = ampAplauso.analyze();
  if (vol > AMP_MIN_Aplauso && vol < AMP_MAX_Aplauso) {
    float tam = map(vol, AMP_MIN_Aplauso, AMP_MAX_Aplauso, 10, 500);
    ondaExpansiva.setSize(tam);
    ondaExpansiva.setFill(0, 255, 0, 50);
  } else {
    ondaExpansiva.setSize(10);
    ondaExpansiva.setFill(0, 0);
  }
}


void dibujarOndaExpansiva() {
  stroke(0, 255, 0, 150);
  if (ondaExpansiva.getSize() > 40) {
  strokeWeight(2);
  } else {
  strokeWeight(0);
  }
  // println (ondaExpansiva.getSize());
  noFill();
  ellipse(ondaExpansiva.getX(), ondaExpansiva.getY(), ondaExpansiva.getSize(), ondaExpansiva.getSize());
}

void crearPelotitas() {
  float vol = ampDialogo.analyze();
  if (vol > AMP_MIN_Dialogo && vol < AMP_MAX_Dialogo && millis() - lastTomateTime > 300) { // Cada segundo aprox.
    createTomate();
    lastTomateTime = millis();
  }
  for (TomateAnimado tomate : tomates) {
    tomate.dibujar();
  }
}

// ---- Funciones auxiliares ----

void findAndSimplifyLargestPolygon() {
  if (poly != null) world.remove(poly);

  opencv.findContours();
  ArrayList<Contour> contours = opencv.findContours();

  if (contours.size() > 0) {
    Contour largestContour = contours.get(0);
    for (Contour contour : contours) {
      if (contour.area() > largestContour.area()) largestContour = contour;
    }

    largestContour = largestContour.getPolygonApproximation();
    poly = new FPoly();
    ArrayList<PVector> points = largestContour.getPoints();

    // Calcular centroide
    float sumX = 0;
    float sumY = 0;
    for (PVector point : points) {
      poly.vertex(point.x, point.y);
      sumX += point.x;
      sumY += point.y;
    }
    centroidX = sumX / points.size();
    centroidY = sumY / points.size();

    // Suavizar transición entre centroides
    interpolatedX = lerp(interpolatedX, centroidX, smoothFactor);
    interpolatedY = lerp(interpolatedY, centroidY, smoothFactor);

    poly.setStatic(true);

    // Verificar la posición del centroide
    float leftThreshold = width * 0.2; // Umbral del 20% del ancho para el lado izquierdo
    float rightThreshold = width * 0.8; // Umbral del 80% del ancho para el lado derecho

    if (centroidX < leftThreshold || centroidX > rightThreshold) {
      // Centroide está demasiado a la izquierda o a la derecha
      poly.setFill(255, 100); // Cambiar a verde transparente
      redOpacity = 0;
    } else if (!isFilledRed) {
      poly.setFill(255, 100); 
    } else {
      poly.setFill(255, 0, 0, redOpacity);
    }

     world.add(poly); 

    // Actualizar posición de la onda expansiva
    ondaExpansiva.setPosition(interpolatedX, interpolatedY);
  }
}


void createTomate() {
  TomateAnimado tomate = new TomateAnimado(20, frames);
  float xStart;
  float velocityX;
  tomate.circulo.setRestitution(10.0);

  // Lado aleatorio
  if (random(1) < 0.5) {
    xStart = 10; // Lado izquierdo
    velocityX = random(300, 500); // Velocidad hacia la derecha
  } else {
    xStart = width - 10; // Lado derecho
    velocityX = random(-300, -150); // Velocidad hacia la izquierda
  }

  // Posición inicial aleatoria en Y
  tomate.circulo.setPosition(xStart, random(50, 150));
  tomate.circulo.setDensity(1.0);
  tomate.circulo.setVelocity(velocityX, random(-100, -200));
  world.add(tomate.circulo);
  tomates.add(tomate);
}
class TomateAnimado {
  FCircle circulo;
  PImage[] frames;
  int currentFrame;

  TomateAnimado(float radius, PImage[] frames) {
    this.circulo = new FCircle(radius);
    this.frames = frames;
    this.currentFrame = 0;
    this.circulo.setFill(0, 0); // Invisible por defecto
    this.circulo.setStroke(0, 0);
  }

  void dibujar() {
    // Sincronizar posición del video con el círculo
    imageMode(CENTER);
    image(frames[currentFrame], circulo.getX(), circulo.getY(), 96, 54);

    // Avanzar al siguiente frame
    currentFrame = (currentFrame + 1) % frames.length;
  }
}

void contactStarted(FContact c) {

  if ((c.getBody1() instanceof FCircle && c.getBody2() == poly) ||
    (c.getBody2() instanceof FCircle && c.getBody1() == poly)) {
    fillProgress = min(fillProgress + 0.1, 1.0); // Incrementa hasta 100%
    isFilledRed = true;
    redOpacity = min(redOpacity + 10, 255); // Aumentar opacidad hasta 255
    poly.setFill(255, 0, 0, redOpacity); // Cambiar a rojo con nueva opacidad

    // Eliminar la pelota tras la colisión
    FBody tomateBody = (c.getBody1() instanceof FCircle) ? c.getBody1() : c.getBody2();

    // Buscar el TomateAnimado correspondiente al FCircle
    TomateAnimado tomateAEliminar = null;
    for (TomateAnimado tomate : tomates) {
      if (tomate.circulo == tomateBody) {
        tomateAEliminar = tomate;
        break;
      }
    }

    if (tomateAEliminar != null) {
      world.remove(tomateAEliminar.circulo); // Eliminar del mundo
      tomates.remove(tomateAEliminar); // Eliminar de la lista
      tomatazo.play();
    }
  }
}

void stop() {
  micDialogo.stop();
  micAplauso.stop();
  super.stop();
}

void keyPressed(){
if(key=='r') {
 poly.setFill(0, 255, 0, 0);
 redOpacity = 0;
}



}
