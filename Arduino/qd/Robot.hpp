//
//  Robot.hpp
//  qd
//
//  Created by Edward Janne on 10/18/23.
//

#ifndef Robot_hpp
#define Robot_hpp

#define PI 3.141592653589793
#define PIOver2 1.570796326794897
#define TwoPI 6.283185307179586

#include <stdio.h>

#include "LinearAlgebra.hpp"

// #define RAD_TO_DEG(rad) (rad * 180.0 / PI)

typedef struct Robot {
    typedef struct Limb {
        typedef enum Configuration {
            frontRight = 0,
            frontLeft = 1,
            backRight = 2,
            backLeft = 3
        } Config;
        
        Configuration configuration;
        Vector4 rootOffset;
        float l0;
        float l0sq;
        float l1;
        float l1sq;
        float l2;
        float l2sq;
        
        float hipAngle, shoulderAngle, elbowAngle;
        
        Limb(Configuration iConfig, const Vector4 &iRootOffset, float iHipToShoulder, float iShoulderToElbow, float iElbowToToe);
        
        Vector4 normalizeTarget(const Vector4 &iTarget) const;
        Vector4 denormalizeTarget(const Vector4 &iNormalized) const;
        
        void calcIKAngles(const Vector4 &iTarget);

        float operator[](int i) const;
        float &operator[](int i);
        
    } Limb;
    
    Limb limbs[4];
    Vector4 ikTargets[4];
    
    Robot(float iHipToShoulder, float iShoulderToElbow, float iElbowToToe, const Vector4 &iFrontRightRootPosition, const Vector4 &iFrontLeftRootPosition, const Vector4 &iBackRightRootPosition, const Vector4 &iBackLeftRootPosition);
    
    void setIKTargets(const Vector4 &iFrontRightTarget, const Vector4 &iFrontLeftTarget, const Vector4 &iBackRightTarget, const Vector4 &iBackLeftTarget);
    void setAngles(const Vector4 &iHipAngles, const Vector4 &iShoulderAngles, const Vector4 &iElbowAngles);
    
    void update();
    
    void printIKAngles() const;
} Robot;

#endif /* Robot_hpp */
