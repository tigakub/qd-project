//
//  LinearAlgebra.hpp
//  qd
//
//  Created by Edward Janne on 10/18/23.
//

#ifndef LinearAlgebra_hpp
#define LinearAlgebra_hpp

#include <stdio.h>

// #define COLUMN_MAJOR

typedef struct Vector4 {
    static Vector4 i;
    static Vector4 j;
    static Vector4 k;
    
    float v[4];
    
    Vector4(float x = 0.0, float y = 0.0, float z = 0.0, float w = 0.0);
    Vector4(const float *iVector);
    Vector4(const Vector4 &iOther);
    
    float operator[](int i) const;
    float &operator[](int i);
    
    Vector4 &operator=(const Vector4 &iVec);
    
    Vector4 &operator+=(const Vector4 &iVec);
    Vector4 &operator-=(const Vector4 &iVec);
    Vector4 &operator*=(float iScal);
    Vector4 &operator/=(float iScal);
    
    Vector4 operator+(const Vector4 &iVec) const;
    Vector4 operator-(const Vector4 &iVec) const;
    Vector4 operator*(float iScal) const;
    Vector4 operator/(float iScal) const;
    
    Vector4 operator!() const;                      // Normalized
    
    float operator*(const Vector4 &iVec) const;     // Dot product
    Vector4 operator/(const Vector4 &iVec) const;   // Cross product
    
    Vector4 operator>(const Vector4 &iVec) const;   // Projection
    Vector4 operator^(const Vector4 &iVec) const;   // Perpendicular
    
} Vector4;

typedef struct Matrix4 {
    float m[16];
    
    Matrix4(int iMode);
    Matrix4(const float *iMatrix);
    Matrix4(const Vector4 &iAxis, float iAngle);
    Matrix4(const Matrix4 &iOther);
    
    Matrix4 operator *(const Matrix4 &iMat);
    Vector4 operator *(const Vector4 &iVec);
    
    float operator[](int i) const;
    float &operator[](int i);
} Matrix4;

#endif /* LinearAlgebra_hpp */
