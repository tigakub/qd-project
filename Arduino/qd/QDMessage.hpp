#include <stdint.h>

struct QDPoseSwapped;

typedef struct QDPose {
    uint32_t type;
    float hips[4];
    float shoulders[4];
    float elbows[4];
    uint32_t timestamp;

    QDPose(const QDPoseSwapped &iPose);
} QDPose;

struct QDFeedbackSwapped;

typedef struct QDFeedback {
    uint32_t type;
    float hips[4];
    float shoulders[4];
    float elbows[4];
    float orientation[4];

    QDFeedback(const QDFeedbackSwapped &iFeedback);
} QDFeedback;

typedef struct QDPoseSwapped {
    uint32_t type;
    uint32_t hips[4];
    uint32_t shoulders[4];
    uint32_t elbows[4];
    uint32_t timestamp;

    QDPoseSwapped(const QDPose &iPose);
} QDPoseSwapped;

typedef struct QDFeedbackSwapped {
    uint32_t type;
    uint32_t hips[4];
    uint32_t shoulders[4];
    uint32_t elbows[4];
    uint32_t orientation[4];

    QDFeedbackSwapped(const QDFeedback &iFeedback);
} QDFeedbackSwapped;