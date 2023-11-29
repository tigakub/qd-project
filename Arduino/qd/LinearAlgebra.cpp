//
//  LinearAlgebra.cpp
//  qd
//
//  Created by Edward Janne on 10/18/23.
//

#include "LinearAlgebra.hpp"
#include <utility>
#include <math.h>

Vector4 Vector4::i(1.0, 0.0, 0.0);
Vector4 Vector4::j(0.0, 1.0, 0.0);
Vector4 Vector4::k(0.0, 0.0, 1.0);

Vector4::Vector4(float x, float y, float z, float w)
: v { x, y, z, w }
{ }

Vector4::Vector4(const float *iVector)
: v { iVector[0], iVector[1], iVector[2], iVector[3] }
{ }

Vector4::Vector4(const Vector4 &iOther)
: v { iOther[0], iOther[1], iOther[2], iOther[3] }
{ }
    
float Vector4::operator[](int i) const {
    return v[i];
}

float &Vector4::operator[](int i) {
    return v[i];
}

Vector4 &Vector4::operator=(const Vector4 &iVec) {
    int i = 4;
    while(i--) v[i] = iVec[i];
    return *this;
}
    
Vector4 &Vector4::operator+=(const Vector4 &iVec) {
    int i = 4;
    while(i--) v[i] += iVec[i];
    return *this;
}

Vector4 &Vector4::operator-=(const Vector4 &iVec) {
    int i = 4;
    while(i--) v[i] -= iVec[i];
    return *this;
}

Vector4 &Vector4::operator*=(float iScal) {
    int i = 4;
    while(i--) v[i] *= iScal;
    return *this;
}

Vector4 &Vector4::operator/=(float iScal) {
    int i = 4;
    float r = 1.0 / iScal;
    while(i--) v[i] *= r;
    return *this;
}

Vector4 Vector4::operator+(const Vector4 &iVec) const {
    Vector4 result(*this);
    result += iVec;
    return result;
}

Vector4 Vector4::operator-(const Vector4 &iVec) const {
    Vector4 result(*this);
    result -= iVec;
    return result;
}

Vector4 Vector4::operator*(float iScal) const {
    Vector4 result(*this);
    result *= iScal;
    return result;
}

Vector4 Vector4::operator/(float iScal) const {
    Vector4 result(*this);
    result /= iScal;
    return result;
}
    
Vector4 Vector4::operator!() const {
    Vector4 result(*this);
    result /= sqrtf(*this * *this);
    return result;
}

float Vector4::operator*(const Vector4 &iVec) const {
    return v[0] * iVec[0] + v[1] * iVec[1] + v[2] * iVec[2];
}

Vector4 Vector4::operator/(const Vector4 &iVec) const {
    return Vector4(v[1] * iVec[2] - v[2] * iVec[1], v[2] * iVec[0] - v[0] * iVec[2], v[0] * iVec[1] - v[1] * iVec[0]);
}
    
Vector4 Vector4::operator>(const Vector4 &iVec) const {
    return iVec * ((*this * iVec) / (iVec * iVec));
}

Vector4 Vector4::operator^(const Vector4 &iVec) const {
    return *this - (*this > iVec);
}

Matrix4::Matrix4(int iMode)
: m { 0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0 }
{
    int i = 16;
    while(i--) {
        m[i] = ((iMode && (i % 5 == 0)) ? 1.0 : 0.0);
    }
}

Matrix4::Matrix4(const float *iMatrix)
: m { 0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0 }
{
    int i = 16;
    while(i--) {
        m[i] = iMatrix[i];
    }
}

Matrix4::Matrix4(const Vector4 &iAxis, float iAngle)
: m { 0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.0, 0.0 }
{
    float s = sinf(iAngle);
    float c = cosf(iAngle);
    float cc = (1.0 - c);
    float x = iAxis[0], y = iAxis[1], z = iAxis[2],
          xs = x * x, ys = y * y, zs = z * z;
    #ifdef COLUMN_MAJOR
    m[0] = c + xs * cc;
    m[4] = x * y * cc - z * s;
    m[8] = x * z * cc + y * s;
    m[12] = 0.0;
    m[1] = x * y * cc + z * s;
    m[5] = c + ys * cc;
    m[9] = y * z * cc - x * s;
    m[13] = 0.0;
    m[2] = x * z * cc - y * s;
    m[6] = y * z * cc + x * s;
    m[10] = c + zs * cc;
    m[14] = 0.0;
    m[3] = 0.0;
    m[7] = 0.0;
    m[11] = 0.0;
    m[15] = 1.0;
    #else
    m[0] = c + xs * cc;
    m[1] = x * y * cc - z * s;
    m[2] = x * z * cc + y * s;
    m[3] = 0.0;
    m[4] = x * y * cc + z * s;
    m[5] = c + ys * cc;
    m[6] = y * z * cc - x * s;
    m[7] = 0.0;
    m[8] = x * z * cc - y * s;
    m[9] = y * z * cc + x * s;
    m[10] = c + zs * cc;
    m[11] = 0.0;
    m[12] = 0.0;
    m[13] = 0.0;
    m[14] = 0.0;
    m[15] = 1.0;
    #endif
}

float Matrix4::operator[](int i) const {
    return m[i];
}

float &Matrix4::operator[](int i) {
    return m[i];
}
    
Matrix4 Matrix4::operator*(const Matrix4 &iMat) {
    Matrix4 result(0);
    
    int i = 16;
    while(i--) {
        int x = i % 4;
        int y = i / 4;
        int j = 4;
        #ifdef COLUMN_MAJOR
        // Column major
        while(j--) {
            result[x * 4 + y] += m[j * 4 + y] * iMat[x * 4 + j];
        }
        #else
        // Row major
        while(j--) {
            result[y * 4 + x] += m[y * 4 + j] * iMat[j * 4 + x];
        }
        #endif
    }
    return result;
}

Vector4 Matrix4::operator*(const Vector4 &iVec) {
    Vector4 result;
    
    int y = 4;
    while(y--) {
        int x = 4;
        while(x--) {
            #ifdef COLUMN_MAJOR
            result[x] += m[x * 4 + y] * iVec[x];
            #else
            result[y] += m[y * 4 + x] * iVec[x];
            #endif
        }
    }
    
    return result;
}
