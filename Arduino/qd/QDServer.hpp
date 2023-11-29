#include <SPI.h>
#include <WiFi101.h>
#include <WiFiUdp.h>

class QDServer {
  protected:
    int status = WL_IDLE_STATUS;
    WiFiUDP udp;

    const char *remoteAddress;
    IPAddress remoteIP;
    uint16_t remotePort;
    const char *sendBuffer;
    int sendBufLen;
    int sendBufIndex;
    char *recvBuffer;
    int recvBufLen;
    int recvBufIndex;

  public:
    QDServer();

    // Attempt to join WiFi network
    bool joinNetwork(int attempts = 5);

    void startUDP(const char *iRemoteAddress, uint16_t iRemotePort, int iLocalPort = 3567);

    void setSendInfo(const char *iSendBuffer, int iSendLen);
    void setRecvInfo(char *iRecvBuffer, int iRecvLen);

    int sendLoop();
    int recvLoop();
};
