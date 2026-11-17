//All header file 
#include<SPI.h>
#include<LoRa.h>
#include <WiFi.h>
#include<bits/stdc++.h>
#include <WebSocketsServer.h>



using namespace std;


//All pin connection is here
//for esp32 pin connection
#define SS   5
#define RST  14
#define DIO0 2

// ESP8266 NodeMCU pins
// #define SS    15   // D8
// #define RST   16   // D0
// #define DIO0   4   // D2

set<int>active_client;
WebSocketsServer webSocket = WebSocketsServer(81);


struct wifi_message{
    int num=-1;//if num==-1 then it will send the innermessage to all
    char dataa[256]={};
};

QueueHandle_t send_by_lora;
QueueHandle_t send_by_wifi;


//this data_send_to_all_except_me/    ->wired to direct lora & all device
//    ->capture lora message and send by lora & all device
//    ->for now i just capture lora message and send it to only device not lora ********



int send_data_by_lora(String msg){ //working on core 1
  LoRa.beginPacket();
  LoRa.print(msg);
  return LoRa.endPacket();//if return 1 then it is Success;
}

//add_msg using wired
void add_msg_wired(void *parameter){ //working on core 0
  //send by wifi
  //send by lora
  while(1){
    if (Serial.available()) {
        char input[256];
        size_t len= Serial.readBytesUntil('\n', input, sizeof(input) - 1);
        input[len] = '\0'; //i take the input from keyboard wired

        //for sending data by lora store in queue
        xQueueSend(send_by_lora, &input, pdMS_TO_TICKS(20));

        //for sending data by wifi store in queue
        wifi_message temp;
        memcpy(temp.dataa, input, strlen(input) + 1);
        xQueueSend(send_by_wifi, &temp, pdMS_TO_TICKS(20));
    }
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}

void send_msg_lora(){ //working on core 1(lora)
  unsigned long start = millis();
  while(millis()-start<10){
    char temp[256];
    if(xQueueReceive(send_by_lora, &temp, 0) == pdTRUE){
      if(send_data_by_lora(temp)){
        LoRa.receive();
        //delay(20); no needed because LoRa.endPacket(); it can handled it
        Serial.print("[ sending msg ]");
        Serial.println(temp);
      }
      else{
        Serial.print("[ sending msg Failed.....]");
        Serial.println(temp);
      }
    }
  }
    
}

bool receive_msg(){ //working on core 1(lora)
  int packetSize = LoRa.parsePacket();
  unsigned long start = millis();
  while(millis()-start<50){
    int packetSize = LoRa.parsePacket();
    if (packetSize) {
        char message[256];
        size_t len = 0;
        while (LoRa.available() && len < sizeof(message) - 1) {
            message[len++] = (char)LoRa.read();
        }
        message[len] = '\0';
        // for sending 1 lora to another lora
        Serial.print("[ Received From lora ]: ");
        Serial.println(message);
        Serial.print("RSSI: ");
        Serial.println(LoRa.packetRssi());

        // xQueueSend(send_by_lora, &message, pdMS_TO_TICKS(20));
        wifi_message temp;
        memcpy(temp.dataa, message, strlen(message) + 1);
        xQueueSend(send_by_wifi, &temp, pdMS_TO_TICKS(20));

      //delay(20);//no need
      return true;
    }
  }
  return false;
    
}
void msg(void *parameter){ //core 1 perfectly balanced
  while(1){
    receive_msg();
    send_msg_lora();
    vTaskDelay(pdMS_TO_TICKS(1));//it's nessessary else there a reset or idle problem
  }
}




//web socket
void webSocketEvent(uint8_t num,WStype_t type,uint8_t *payload,size_t length){   //working on core 0
    
    switch (type) {
        case WStype_CONNECTED:
            Serial.printf("Client %d connected\n", num);
            active_client.insert(num);
            webSocket.sendTXT(num, "Hello from ESP32!");
            break;
        case WStype_DISCONNECTED:
            Serial.printf("Client %d disconnected\n", num);
            active_client.erase(num);
            break;
        case WStype_TEXT:{
            if(!length)return ; // null message handled perfectly
            Serial.printf("[ Received from client %d ] : %s\n",
                          num, payload);
            //all_msg.push(String((char*)payload));//////i just add this in queue
            Serial.println(num);
            // Send message back
            wifi_message temp;
            temp.num=num;
            memcpy(temp.dataa,payload, strlen((char*)payload) + 1);
            char tempp[256];
            memcpy(tempp,payload, strlen((char*)payload) + 1);
            xQueueSend(send_by_wifi, &temp, pdMS_TO_TICKS(20));
            xQueueSend(send_by_lora, &tempp, pdMS_TO_TICKS(20));
        }break;

        case WStype_BIN:
            Serial.println("Binary data received");
            break;

        default:
            break;
    }
}


//Web socket done
void web_socket(){ //working on core 0
  // WebSocket server
    webSocket.begin();
    webSocket.onEvent(webSocketEvent);
    Serial.println("WebSocket server started");
}


//wifi setup done
void wifi_setup(){ //working on core 0
  const char* ssid = "111";
  const char* password = "********"; // set your own Wi-Fi password (min 8 characters)
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, password);
  Serial.println("Hotspot started!");
  Serial.print("IP address: ");
  Serial.println(WiFi.softAPIP());

}

  void data_send_by_wifi(void *parameter){///when too much data comes then the user seen via wifi not works
    while(1){
      wifi_message temp;
      if(xQueueReceive(send_by_wifi, &temp, 0) == pdTRUE){
              for(auto i:active_client){
                if(i==temp.num)continue;
                  Serial.print("Sending data user : ");
                  Serial.println(i);
                  webSocket.sendTXT(i, temp.dataa);
                  vTaskDelay(pdMS_TO_TICKS(1));
              }

      }
      else vTaskDelay(pdMS_TO_TICKS(1));
    }
  }
void setup(){
  Serial.begin(115200);

  //At first all queue initializing

  send_by_lora = xQueueCreate(100, sizeof(char[256]));
  if(send_by_lora==NULL){
    Serial.println("Queue is NULL!");
    return ;
  }
  send_by_wifi = xQueueCreate(100, sizeof(wifi_message));
  if(send_by_wifi==NULL){
    Serial.println("Queue is NULL!");
    return ;
  }
  //queue initializing finished

  //lora initializing
  LoRa.setPins(SS,RST,DIO0);
  while(!LoRa.begin(433E6)){
    Serial.println("Lora initialization failed");
  }
  Serial.println("Lora Is Now Ready");
  //lora initializing finished

  //working on core 0
  wifi_setup();
  web_socket();
  xTaskCreate(add_msg_wired,"add_msg_wired",4096,NULL,0,NULL); //core 0

  //core 1
  xTaskCreate(msg,"Msg",4096,NULL,1,NULL);
  xTaskCreate(data_send_by_wifi,"data_send_to_wifi_f",4096,NULL,0,NULL);
  //xTaskCreate(data_send_to_wifi_except_me,"data_send_to_wifi_except_me",4096,NULL,0,NULL); //still i dont sent the data to lora to lora
}
void loop(){
    webSocket.loop();//core 0
}



