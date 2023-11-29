#include "QDMessage.hpp"
#include <Arduino.h>

uint32_t swap32(uint32_t iValue) {
  uint8_t *ptr = (uint8_t *) &iValue;
  ptr[0] ^= ptr[3];
  ptr[3] ^= ptr[0];
  ptr[0] ^= ptr[3];
  ptr[1] ^= ptr[2];
  ptr[2] ^= ptr[1];
  ptr[1] ^= ptr[2];
  return iValue;
}

#define ntohl swap32
#define htonl swap32

uint32_t htonf(float iValue) {
  return htonl(*((uint32_t *) &iValue));
}

float ntohf(uint32_t iValue) {
  uint32_t hostOrder = ntohl(iValue);
  return *((float *) &hostOrder);
}

QDPose::QDPose(const QDPoseSwapped &iPose)
: type(ntohl(iPose.type)), timestamp(ntohl(iPose.timestamp)) {
  for(int i = 0; i < 4; i++) {
    hips[i] = ntohf(iPose.hips[i]);
    shoulders[i] = ntohf(iPose.shoulders[i]);
    elbows[i] = ntohf(iPose.elbows[i]);
  }
}

QDFeedback::QDFeedback(const QDFeedbackSwapped &iFeedback)
: type(ntohl(iFeedback.type)) {
  for(int i = 0; i < 4; i++) {
    hips[i] = ntohf(iFeedback.hips[i]);
    shoulders[i] = ntohf(iFeedback.shoulders[i]);
    elbows[i] = ntohf(iFeedback.elbows[i]);
    orientation[i] = ntohf(iFeedback.orientation[i]);
  }
}

QDPoseSwapped::QDPoseSwapped(const QDPose &iPose)
: type(htonl(iPose.type)), timestamp(htonl(iPose.timestamp)) {
  for(int i = 0; i < 4; i++) {
    hips[i] = htonf(iPose.hips[i]);
    shoulders[i] = htonf(iPose.shoulders[i]);
    elbows[i] = htonf(iPose.elbows[i]);
  }
}

QDFeedbackSwapped::QDFeedbackSwapped(const QDFeedback &iFeedback)
: type(htonl(iFeedback.type)) {
  for(int i = 0; i < 4; i++) {
    hips[i] = htonf(iFeedback.hips[i]);
    shoulders[i] = htonf(iFeedback.shoulders[i]);
    elbows[i] = htonf(iFeedback.elbows[i]);
    orientation[i] = htonf(iFeedback.orientation[i]);
  }
}
