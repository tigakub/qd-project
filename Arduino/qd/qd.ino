// #include <DynamixelShield.h>
#include "Robot.hpp"
#include "QDServer.hpp"
#include "QDMessage.hpp"

//#define ENABLE_SYNC

Robot qd(42.0, 55.0, 55.0, Vector4(29.0, 0.0, 75.0), Vector4(-29.0, 0.0, 75.0), Vector4(29.0, 0.0, -75.0), Vector4(-29.0, 0.0, -75.0));

const float DXL_PROTOCOL_VERSION = 2.0;

float unitValue = 0.001533980788; // Radians
#define RAD_TO_STEP 651.8986469044
// float unitVlue = 0.087890625; // Degrees

// DynamixelShield *dxl;

//using namespace ControlTableItem;

#ifdef ENABLE_SYNC
typedef struct SRData {
    int32_t presentPosition;
} __attribute__((packed)) SRData;

typedef struct SWData {
    int32_t goalPosition;
} __attribute__((packed)) SWData;

#define PKT_BUF_SIZE 2048
uint8_t pktBuf[PKT_BUF_SIZE];

DYNAMIXEL::InfoSyncReadInst_t srInfo;
DYNAMIXEL::XELInfoSyncRead_t srXELS[12];
SRData srData[12];

DYNAMIXEL::InfoSyncWriteInst_t swInfo;
DYNAMIXEL::XELInfoSyncWrite_t swXELS[12];
SWData swData[12];

#endif

#ifdef ENABLE_SYNC

void initSync() {
  srInfo.packet.p_buf = pktBuf;
  srInfo.packet.buf_capacity = PKT_BUF_SIZE;
  srInfo.packet.is_completed = false;
  srInfo.addr = PRESENT_POSITION;
  srInfo.addr_length = 4;
  srInfo.p_xels = srXELS;
  srInfo.xel_count = 0;

  swInfo.packet.p_buf = nullptr;
  swInfo.packet.is_completed = false;
  swInfo.addr = GOAL_POSITION;
  swInfo.addr_length = 4;
  swInfo.p_xels = swXELS;
  swInfo.xel_count = 0;
  
  int n = 12;
  int j = 4;
  while(j--) {
    int i = 3;
    while(i--) {
      n--;
      int id = j * 10 + i;
      srXELS[n].id = id;
      srXELS[n].p_recv_buf = (uint8_t *) &(srData[n]);
      swXELS[n].id = id;
      swXELS[n].p_data = (uint8_t *) &(swData[n].goalPosition);
    }
  }
  srInfo.xel_count = 12;
  swInfo.xel_count = 12;

  srInfo.is_info_changed = true;
  swInfo.is_info_changed = true;
}
#endif

/*
void readJoints() {

}
*/

/*
bool setJoints() {

  #ifdef ENABLE_SYNC

  int n = 12;
  int j = 4;
  while(j--) {
    int i = 3;
    while(i--) {
      n--;
      int32_t pos = int32_t(round(qd.limbs[j][i] * RAD_TO_STEP));
      swData[n].goalPosition = pos;
    }
  }
  swInfo.is_info_changed = true;
  return dxl->syncWrite(&swInfo);

  #else // !def ENABLE_SYNC

  int j = 4;
  while(j--) {
    int i = 3;
    while(i--) {
      int id = j * 10 + i;
      float tgt = qd.limbs[j][i] * RAD_TO_DEG;
      dxl->setGoalPosition(id, tgt, UNIT_DEGREE);
    }
  }
  return true;

  #endif // ENABLE_SYNC
}
*/

/*
void slerpJoints() {
  int j = 4;
  while(j--) {
    int i = 3;
    while(i--) {
      int id = j * 10 + i;
      float pos = dxl->getPresentPosition(id, UNIT_DEGREE);
      float tgt = qd.limbs[j][i] * RAD_TO_DEG;
      float dist = fabs(pos - tgt);
      float factor = dist / 360.0;
      if(factor > 1.0) {
          factor = 1.0;
      }
      factor *= factor;
      float blend = pos * factor + tgt * (1.0 - factor);
      dxl->setGoalPosition(id, blend, UNIT_DEGREE);
    }
  }
}
*/

const char *remoteIP = "127.0.0.1";
uint16_t remotePort = 3567;
QDServer server;

unsigned long lasttick = 0.0;

void setup() {
  Serial.begin(115200);
  delay(2000);
  // while(!Serial);

  /*
  if(!server.joinNetwork(5)) {
    while(true);
  }

  server.startUDP(remoteIP, remotePort);
  */

  /*
  dxl = new DynamixelShield;
  dxl->begin(57600);
  dxl->setPortProtocolVersion(DXL_PROTOCOL_VERSION);
  */

  #ifdef ENABLE_SYNC
  initSync();
  #endif

  /*
  int j = 4;
  while(j--) {
    int i = 3;
    while(i--) {
      int id = j * 10 + i;
      dxl->writeControlTableItem(RETURN_DELAY_TIME, id, 0);
      dxl->setOperatingMode(id, OP_POSITION);
      float pos = dxl->getPresentPosition(id, UNIT_DEGREE);
      dxl->setGoalPosition(id, pos, UNIT_DEGREE);
      dxl->torqueOn(id);
    }
  }
  */

  lasttick = micros();
}

const float bodyHeight = 100.0;
const float angularSpeed = 1.0;

float angle = 0.0;

Vector4 frontRightTarget(71.0, -bodyHeight, 75.0),
        frontLeftTarget(-71.0, -bodyHeight, 75.0),
        backRightTarget(71.0, -bodyHeight, -75.0),
        backLeftTarget(-71.0, -bodyHeight, -75.0);

const int udpSendBufLen = 81;
char udpSendBuf[udpSendBufLen];

const int udpRecvBufLen = 81;
char udpRecvBuf[udpRecvBufLen];

unsigned long lastus = 0.0;
unsigned long deltas[30];
int ndx = 0;
int count = 0;

void loop() {
    
    unsigned long us = micros();

    if((us - lasttick) > 33333) {
      unsigned long start = micros();
      float offset = 0.0; // 30.0 * sinf(angle);
      float frontLift = 60.0 * sinf(angle) - 30.0;
      float backLift = 60.0 * sinf(angle) - 30.0;
      float forwardShift = -25.0; // 15.0 * sinf(angle) - 15.0;
      if(frontLift < 0.0) frontLift = 0.0;
      if(backLift < 0.0) backLift = 0.0;

      frontRightTarget[0] = 71.0 + offset;
      frontRightTarget[1] = -bodyHeight + frontLift;
      frontRightTarget[2] = 75 - forwardShift;

      frontLeftTarget[0] = -71.0 + offset;
      frontLeftTarget[1] = -bodyHeight;
      frontLeftTarget[2] = 75 + forwardShift;

      backRightTarget[0] = 71.0 + offset;
      backRightTarget[1] = -bodyHeight;
      backRightTarget[2] = -75 - forwardShift;

      backLeftTarget[0] = -71.0 + offset;
      backLeftTarget[1] = -bodyHeight + backLift;
      backLeftTarget[2] = -75 + forwardShift;
      
      qd.setIKTargets(frontRightTarget, frontLeftTarget, backRightTarget, backLeftTarget);
      
      qd.update();
      unsigned long end = micros();
      unsigned long delta = end - start;
      
      deltas[ndx] = delta;
      ndx = (++ndx) % 30;
      if(count < 30) {
        count++;
      }
      unsigned long sum = 0;
      for(int i = 0; i < count; i++) {
        sum += deltas[i];
      }
      sum /= count;
      Serial.println(sum);

      lasttick = us;
    }

    // qd.printIKAngles();

    /*
    if(!setJoints()) {
      Serial.println("Sync-write failed");
    }

    // slerpJoints();

    // Serial.println();

    // delay(250);

    if(angle >= TwoPI) angle = 0.0;
    angle += angularSpeed;
    */

    /*
    if(server.sendLoop() >= 0) {
      // Message complete, ready for next
      server.setSendInfo(udpSendBuf, udpSendBufLen);
    }

    int result = server.recvLoop();
    if(result >= 0) {
      if(result > 0) {
        // Message complete, ready for next
        QDPoseSwapped *swapped = (QDPoseSwapped *) udpRecvBuf;
        QDPose pose(*swapped);
        qd.setAngles(Vector4(pose.hips), Vector4(pose.shoulders), Vector4(pose.elbows));
        // setJoints();
      }
      server.setRecvInfo(udpRecvBuf, udpRecvBufLen);
    }
    */
}
