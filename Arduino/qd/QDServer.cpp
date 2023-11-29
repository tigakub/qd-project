#include "QDServer.hpp"
#include "arduino_secrets.h"
#include <Arduino.h>

char *wifi_ssids[] = SECRET_SSIDS;
char *wifi_passes[] = SECRET_PASSES;

QDServer::QDServer()
: udp(), remoteAddress(nullptr), remotePort(0), sendBuffer(nullptr), sendBufLen(0), sendBufIndex(0), recvBuffer(nullptr), recvBufLen(0), recvBufIndex(0) { }

bool QDServer::joinNetwork(int iAttempts) {
  if(WiFi.status() == WL_NO_SHIELD) {
    Serial.println("WiFi shield not present.");
    return false;
  }

  while(iAttempts--) {
    int arrayLength = sizeof(wifi_ssids) / sizeof(wifi_ssids[0]);
    for(int i = 0; i < arrayLength; i++) {
      Serial.print("Connection to ");
      Serial.print(wifi_ssids[i]);
      Serial.print(" ");
      status = WiFi.begin(wifi_ssids[i], wifi_passes[i]);
      int time = 5;
      while(time--) {
        delay(1000);
        Serial.print(".");
      }

      if(status != WL_CONNECTED) {
        Serial.println(" failed.");
      } else {
        Serial.println(" succeeded.");
        IPAddress ip = WiFi.localIP();
        int dot0 = ip[0];
        int dot1 = ip[1];
        int dot2 = ip[2];
        int dot3 = ip[3];
        Serial.print(dot0);
        Serial.print(".");
        Serial.print(dot1);
        Serial.print(".");
        Serial.print(dot2);
        Serial.print(".");
        Serial.print(dot3);
        Serial.println();

        return true;
      }
    }
  }
  
  return false;
}

void QDServer::startUDP(const char *iRemoteAddress, uint16_t iRemotePort, int iLocalPort) {
  remoteAddress = iRemoteAddress;
  remotePort = iRemotePort;
  udp.begin(iLocalPort);
}

void QDServer::setSendInfo(const char *iSendBuffer, int iSendLen) {
  if(sendBuffer != nullptr) return;
  sendBuffer = iSendBuffer;
  sendBufLen = iSendLen;
  sendBufIndex = 0;
}

void QDServer::setRecvInfo(char *iRecvBuffer, int iRecvLen) {
  if(recvBuffer != nullptr) return;
  recvBuffer = iRecvBuffer;
  recvBufLen = iRecvLen;
  recvBufIndex = 0;
}

int QDServer::sendLoop() {
  if(!sendBuffer || !remoteAddress) return 0;
  if(!sendBufIndex) {
    if(remoteAddress) {
      udp.beginPacket(remoteAddress, remotePort);
    } else if(remoteIP[0] || remoteIP[3]) {
      udp.beginPacket(remoteIP, remotePort);
    }
  }
  udp.write(sendBuffer[sendBufIndex]);
  sendBufIndex++;
  if(sendBufIndex >= sendBufLen) {
    udp.endPacket();
    int byteCount = sendBufIndex;
    sendBuffer = nullptr;
    sendBufLen = 0;
    sendBufIndex = 0;
    return byteCount;
  }
  return -1;
}

int QDServer::recvLoop() {
  if(!recvBuffer) return 0;
  if(!recvBufIndex) {
    if(!udp.parsePacket()) {
      // Serial.println("No data available.");
      return 0;
    }
    // Serial.println("Received data on UDP!");
    remoteIP = udp.remoteIP();
    remotePort = udp.remotePort();
  }
  recvBuffer[recvBufIndex] = udp.read();
  recvBufIndex++;
  if(recvBufIndex >= recvBufLen) {
    // Serial.println(recvBuffer);
    int byteCount = recvBufIndex;
    recvBuffer = nullptr;
    recvBufLen = 0;
    recvBufIndex = 0;
    return byteCount;
  }
  return -1;
}