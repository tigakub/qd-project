//
//  Robot.cpp
//  qd
//
//  Created by Edward Janne on 10/18/23.
//

#include "Robot.hpp"
#include <math.h>
#include <iostream>
#include <Arduino.h>

Robot::Limb::Limb(Robot::Limb::Configuration iConfig, const Vector4 &iRootOffset, float iHipToShoulder, float iShoulderToElbow, float iElbowToToe)
: configuration(iConfig),
  rootOffset(iRootOffset),
  l0(iHipToShoulder), l0sq(l0 * l0),
  l1(iShoulderToElbow), l1sq(l1 * l1),
  l2(iElbowToToe), l2sq(l2 * l2)
{ }
        
Vector4 Robot::Limb::normalizeTarget(const Vector4 &iTarget) const {
    Vector4 normalized = iTarget - rootOffset;
    switch(configuration) {
        case frontLeft:
        case backLeft: {
                Matrix4 rotation = Matrix4(Vector4::j, PI);
                normalized = rotation * normalized;
            }
            break;
        default:
            break;
    }
    return normalized;
}

Vector4 Robot::Limb::denormalizeTarget(const Vector4 &iNormalized) const {
    Vector4 target;
    switch(configuration) {
        case frontLeft:
        case backLeft: {
                Matrix4 rotation = Matrix4(Vector4::j, -PI);
                target = rotation * iNormalized;
            }
            break;
        default:
            break;
    }
    return target + rootOffset;
}

void Robot::Limb::calcIKAngles(const Vector4 &iTarget) {
    float dsq = iTarget[0] * iTarget[0] + iTarget[1] * iTarget[1];
    float d = sqrtf(dsq);
    float e = acosf(l0 / d);
    float n = 1.0 / d;
    Vector4 unitp(iTarget[0] * n, iTarget[1] * n, 0.0);
    Matrix4 mat(Vector4::k, e);
    Vector4 v(mat * unitp * l0);
    hipAngle = -atan2f(v[1], v[0]);
    Vector4 p(iTarget - v);
    dsq = p * p;
    d = sqrtf(dsq);
    float at = asinf(iTarget[2] / d);
    float ae = (l1 + l2 > d) ? acosf(0.5 * (l1sq + l2sq - dsq) / (l1 * l2)) : PI;
    float a1 = (l1 + l2 > d) ? acosf(0.5 * (l1sq + dsq - l2sq) / (l1 * d)) : 0.0;
    
    switch(configuration) {
        case frontLeft:
        case backLeft:
            shoulderAngle = at + a1 - PIOver2;
            elbowAngle = PI - ae;
            break;
        default:
            hipAngle *= -1.0;
            shoulderAngle = PIOver2 - (at + a1);
            elbowAngle = ae - PI;
    }
    
    hipAngle += PI;
    shoulderAngle += PI;
    elbowAngle += PI;
}

float Robot::Limb::operator[](int i) const {
  switch(i) {
    case 0:
      return hipAngle;
    case 1:
      return shoulderAngle;
    default:
      return elbowAngle;
  }
}

float &Robot::Limb::operator[](int i) {
  switch(i) {
    case 0:
      return hipAngle;
    case 1:
      return shoulderAngle;
    default:
      return elbowAngle;
  }
}

Robot::Robot(float iHipToShoulder, float iShoulderToElbow, float iElbowToToe, const Vector4 &iFrontRightRootPosition, const Vector4 &iFrontLeftRootPosition, const Vector4 &iBackRightRootPosition, const Vector4 &iBackLeftRootPosition)
: limbs {
        limbs[0] = Limb(Limb::frontRight, iFrontRightRootPosition, iHipToShoulder, iShoulderToElbow, iElbowToToe),
        limbs[1] = Limb(Limb::frontLeft, iFrontLeftRootPosition, iHipToShoulder, iShoulderToElbow, iElbowToToe),
        limbs[2] = Limb(Limb::backRight, iBackRightRootPosition, iHipToShoulder, iShoulderToElbow, iElbowToToe),
        limbs[3] = Limb(Limb::backLeft, iBackLeftRootPosition, iHipToShoulder, iShoulderToElbow, iElbowToToe)
    }
{ }

void Robot::setIKTargets(const Vector4 &iFrontRightTarget, const Vector4 &iFrontLeftTarget, const Vector4 &iBackRightTarget, const Vector4 &iBackLeftTarget) {
    ikTargets[0] = limbs[0].normalizeTarget(iFrontRightTarget);
    ikTargets[1] = limbs[1].normalizeTarget(iFrontLeftTarget);
    ikTargets[2] = limbs[2].normalizeTarget(iBackRightTarget);
    ikTargets[3] = limbs[3].normalizeTarget(iBackLeftTarget);
}

void Robot::setAngles(const Vector4 &iHipAngles, const Vector4 &iShoulderAngles, const Vector4 &iElbowAngles) {
    int i = 4;
    while(i--) {
      limbs[i][0] = iHipAngles[i];
      limbs[i][1] = iShoulderAngles[i];
      limbs[i][2] = iElbowAngles[i];
    }
}

void Robot::update() {
    int i = 4;
    while(i--) {
        limbs[i].calcIKAngles(ikTargets[i]);
    }
}

char *frontRight = "Front right: ";
char *frontLeft = "Front left: ";
char *backRight = "Back right: ";
char *backLeft = "Back left: ";

char *strings[] = { frontRight, frontLeft, backRight, backLeft };

void Robot::printIKAngles() const {
    for(int i = 0; i < 4; i++) {
      Serial.print(strings[i]);
      float hipAngle = RAD_TO_DEG * limbs[i].hipAngle;
      float shoulderAngle = RAD_TO_DEG * limbs[i].shoulderAngle;
      float elbowAngle = RAD_TO_DEG * limbs[i].elbowAngle;
      Serial.print(hipAngle);
      Serial.print(", ");
      Serial.print(shoulderAngle);
      Serial.print(", ");
      Serial.println(elbowAngle);
    }

    /*
    std::cout << "Front right: " << RAD_TO_DEG(limbs[0].hipAngle) << ", " << RAD_TO_DEG(limbs[0].shoulderAngle) << ", " << RAD_TO_DEG(limbs[0].elbowAngle) << std::endl;
    std::cout << "Front left:  " << RAD_TO_DEG(limbs[1].hipAngle) << ", " << RAD_TO_DEG(limbs[1].shoulderAngle) << ", " << RAD_TO_DEG(limbs[1].elbowAngle) << std::endl;
    std::cout << "Back right:  " << RAD_TO_DEG(limbs[2].hipAngle) << ", " << RAD_TO_DEG(limbs[2].shoulderAngle) << ", " << RAD_TO_DEG(limbs[2].elbowAngle) << std::endl;
    std::cout << "Back left:   " << RAD_TO_DEG(limbs[3].hipAngle) << ", " << RAD_TO_DEG(limbs[3].shoulderAngle) << ", " << RAD_TO_DEG(limbs[3].elbowAngle) << std::endl;
    */
}
