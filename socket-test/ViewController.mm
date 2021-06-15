//
//  ViewController.m
//  socket-test
//
//  Created by Natale Galioto on 03/06/21.
//

#import "ViewController.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <errno.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <iostream>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>

#include "NetworkInterface.h"
#include <vector>


#define INVALID_SOCKET -1
#define closesocket(s) close(s);
#define ioctlsocket(a,b,c) ioctl(a,b,c)

@interface ViewController ()

@end

int sockt;
struct sockaddr_in local_host;       // Information about the local
struct sockaddr_in remote_host;    // Information about the remote


std::vector<NetworkInterface> availableInterfaces;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refreshNetworkInterfacesButton: nil];
    
    triggerLocalNetworkPrivacyAlertObjC();
    
    sockt = -1;
}


- (IBAction)refreshNetworkInterfacesButton:(id)sender {
    availableInterfaces = GetInterfacesList();
    [self.interfacesSelector removeAllSegments];
    
    for (const auto &i : availableInterfaces) {
        [self.interfacesSelector insertSegmentWithTitle:[NSString stringWithFormat:@"%s (%s)", i.name.c_str(), i.address.c_str()] atIndex:self.interfacesSelector.numberOfSegments animated:NO];
    }
}


std::vector<NetworkInterface> GetInterfacesList() {
    std::vector<NetworkInterface> interfaces;
    
    struct ifaddrs *addrs;
    int result = getifaddrs(&addrs);
    if ( result < 0 ) {
#ifdef DEBUG_NETWORK_SOCKETS
        cout << "Some problem HERE!" << endl;
#endif
        return interfaces;
    }
    
    const struct ifaddrs *cursor = addrs;
    while ( cursor != NULL ) {
        #ifdef DEBUG_NETWORK_SOCKETS
            //inet_ntop(AF_INET, &cursor->ifa_dstaddr->sa_data[2], broadcastAddress, INET_ADDRSTRLEN);
        if (cursor->ifa_addr->sa_family == AF_INET) {
        }
        #endif
        
        if ( cursor->ifa_addr->sa_family == AF_INET
            && !(cursor->ifa_flags & IFF_LOOPBACK)
            && (cursor->ifa_flags & IFF_POINTOPOINT)
            && !(cursor->ifa_flags & IFF_BROADCAST) )
        {
            NetworkInterface iface;
            iface.name = cursor->ifa_name;
            iface.address = inet_ntoa(((struct sockaddr_in *) cursor->ifa_addr)->sin_addr);
            iface.mask = inet_ntoa(((struct sockaddr_in *) cursor->ifa_netmask)->sin_addr);
            iface.broadcast = inet_ntoa(((struct sockaddr_in *) cursor->ifa_dstaddr)->sin_addr);

            interfaces.push_back(iface);
        }
        
        if ( cursor->ifa_addr->sa_family == AF_INET
            && !(cursor->ifa_flags & IFF_LOOPBACK)
            && !(cursor->ifa_flags & IFF_POINTOPOINT)
            &&  (cursor->ifa_flags & IFF_BROADCAST) )
        {
            NetworkInterface iface;
            iface.name = cursor->ifa_name;
            iface.address = inet_ntoa(((struct sockaddr_in *) cursor->ifa_addr)->sin_addr);
            iface.mask = inet_ntoa(((struct sockaddr_in *) cursor->ifa_netmask)->sin_addr);
            iface.broadcast = inet_ntoa(((struct sockaddr_in *) cursor->ifa_dstaddr)->sin_addr);

            interfaces.push_back(iface);
        }
        cursor = cursor->ifa_next;
    }
    
    return interfaces;
}


- (IBAction)initSocketButtonClicked:(id)sender {
    if (sockt != INVALID_SOCKET) {
        close(sockt);
        sockt = -1;
    }
    
    sockt = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    
    if (sockt == INVALID_SOCKET)
    {
        std::cerr << "Could not initialize socket." << std::endl;
        return;
    }
    
    //  opt = 1;
    //  setsockopt(sockt, SOL_SOCKET, SO_BROADCAST, (char *) &opt, sizeof(opt));
    
    // Set nonblocking
    unsigned long blockmode = 1;
    if (ioctlsocket(sockt, FIONBIO, &blockmode) != 0) {
        closesocket(sockt);
        std::cerr << "Socket creation error (2)..." <<std::endl;
        return;
    }
    
    // Disable SIGPIPE
    int value = 1;
    setsockopt(sockt, SOL_SOCKET, SO_NOSIGPIPE, &value, sizeof(value));
    
    // Server (Local)
    memset((void *)&local_host, '\0', sizeof(struct sockaddr_in));
    //local_length = sizeof(struct sockaddr_in);
        
    NetworkInterface &i = availableInterfaces[self.interfacesSelector.selectedSegmentIndex];

    
    local_host.sin_family = PF_INET;
    //local_host.sin_addr.s_addr = inet_addr(i.address.c_str());
    local_host.sin_addr.s_addr = INADDR_ANY;
    local_host.sin_port = htons(1024);
        
    if (::bind(sockt, (struct sockaddr *) &local_host, sizeof(struct sockaddr_in)))
    {
        std::cerr << "ERROR: Couldn't bind to local port." << std::endl;
        return;
    }

//    int opt = 1;
//    int ret = setsockopt(sockt, SOL_SOCKET, SO_BROADCAST, (char *) &opt, sizeof(opt));
//    if (ret)
//    {
//        std::cerr << "cannot set broadcast mode!" << std::endl;
//    }

    

    unsigned int index = if_nametoindex(i.name.c_str());
    int result = setsockopt(sockt, IPPROTO_IP, IP_BOUND_IF,  (char*) &index, sizeof(index));
    if (result) {
        std::cout << "Could not bind to interface " << i.name << std::endl;
    }


}



- (int) receiveFromUDP {
    const size_t MAX_SZ = 1024;
    char buf[MAX_SZ];
    char buf2[MAX_SZ];
    memset(buf, 0, MAX_SZ);
    memset(buf2, 0, MAX_SZ);

    struct sockaddr_in temp_host;      // Information about the remote address
    
    int len = 0;
    
    try
    {
        struct timeval timeout;
        timeout.tv_sec = 1;
        timeout.tv_usec = 250000;
        
        fd_set read_fds;
        FD_ZERO(&read_fds);
        FD_SET(sockt, &read_fds);

        int result = select(sockt+1, &read_fds, NULL, NULL, &timeout);
        if ((result > 0) && FD_ISSET(sockt, &read_fds))
        {
            socklen_t sockaddr_length = sizeof(sockaddr_in);
            len = (int)recvfrom(sockt, buf, MAX_SZ, 0, (struct sockaddr *)&temp_host, &sockaddr_length);
            
            
            for (int i = 0; i < len; i++) {
                sprintf(buf2 + strlen(buf2), "%02x ", (unsigned char)buf[i]);
            }
            
            self.receivedText.text = [NSString stringWithFormat:@"%s", buf2];
        } else {
            std::cout << "Timed out." << std::endl;
        }
    }
    catch (...)
    {
        std::cerr << "Errore<AHHAHAHH" << std::endl;
    }
    
    return len;
}

int value = 0;

- (IBAction)sendTextButtonClicked:(id)sender {
    char buf[256];

//    sprintf(buf, "%d", ++value);
//    self.sentText.text = [NSString stringWithFormat: @"%s", buf];
//    size_t packet_size = strlen(buf);


    buf[0] = 0xAB;
    buf[1] = 0xCD;
    buf[2] = 0xEF;
    buf[3] = 0x01;
    size_t packet_size = 4;
    
    
    memset((void *)&remote_host, '\0', sizeof(struct sockaddr_in));
    remote_host.sin_family = AF_INET;
    remote_host.sin_addr.s_addr = inet_addr(self.destinationIP.text.UTF8String);
    remote_host.sin_port = htons(1024);

    self.sentText.text = [NSString stringWithFormat: @"send status nr %d", ++value];
    
    //IncrementRemotePort();
    int n = -1;
    try {
        n = (int)sendto(sockt, buf, packet_size, 0, (struct sockaddr *)&remote_host, sizeof(struct sockaddr_in));
        
        if (n < 0) {
            int e = errno;
            std::cerr << e << " (" << strerror(e) << ")" << std::endl;
        }
    } catch (...) {
        std::cout << " ERROR" << std::endl;
    }
    
    std::cout << "Bytes sent: " << n << std::endl;
    
    [self receiveFromUDP];
}











#include <ifaddrs.h>
#include <sys/socket.h>
#include <net/if.h>
#include <netinet/in.h>
/// Returns the addresses of the discard service (port 9) on every
/// broadcast-capable interface.
///
/// Each array entry contains either a `sockaddr_in` or `sockaddr_in6`.
static NSArray<NSData *> * addressesOfDiscardServiceOnBroadcastCapableInterfaces(void) {
    struct ifaddrs * addrList = NULL;
    int err = getifaddrs(&addrList);
    if (err != 0) {
        return @[];
    }
    NSMutableArray<NSData *> * result = [NSMutableArray array];
    for (struct ifaddrs * cursor = addrList; cursor != NULL; cursor = cursor->ifa_next) {
        if ( (cursor->ifa_flags & IFF_BROADCAST) &&
             (cursor->ifa_addr != NULL)
           ) {
            switch (cursor->ifa_addr->sa_family) {
            case AF_INET: {
                struct sockaddr_in sin = *(struct sockaddr_in *) cursor->ifa_addr;
                sin.sin_port = htons(9);
                NSData * addr = [NSData dataWithBytes:&sin length:sizeof(sin)];
                [result addObject:addr];
            } break;
            case AF_INET6: {
                struct sockaddr_in6 sin6 = *(struct sockaddr_in6 *) cursor->ifa_addr;
                sin6.sin6_port = htons(9);
                NSData * addr = [NSData dataWithBytes:&sin6 length:sizeof(sin6)];
                [result addObject:addr];
            } break;
            default: {
                // do nothing
            } break;
            }
        }
    }
    freeifaddrs(addrList);
    return result;
}
/// Does a best effort attempt to trigger the local network privacy alert.
///
/// It works by sending a UDP datagram to the discard service (port 9) of every
/// IP address associated with a broadcast-capable interface interface. This
/// should trigger the local network privacy alert, assuming the alert hasn’t
/// already been displayed for this app.
///
/// This code takes a ‘best effort’. It handles errors by ignoring them. As
/// such, there’s guarantee that it’ll actually trigger the alert.
///
/// - note: iOS devices don’t actually run the discard service. I’m using it
/// here because I need a port to send the UDP datagram to and port 9 is
/// always going to be safe (either the discard service is running, in which
/// case it will discard the datagram, or it’s not, in which case the TCP/IP
/// stack will discard it).
///
/// There should be a proper API for this (r. 69157424).
///
/// For more background on this, see [Triggering the Local Network Privacy Alert](https://developer.apple.com/forums/thread/663768).
extern void triggerLocalNetworkPrivacyAlertObjC(void) {
    int sock4 = socket(AF_INET, SOCK_DGRAM, 0);
    int sock6 = socket(AF_INET6, SOCK_DGRAM, 0);
    
    if ((sock4 >= 0) && (sock6 >= 0)) {
        char message = '!';
        NSArray<NSData *> * addresses = addressesOfDiscardServiceOnBroadcastCapableInterfaces();
        for (NSData * address in addresses) {
            int sock = ((const struct sockaddr *) address.bytes)->sa_family == AF_INET ? sock4 : sock6;
            (void) sendto(sock, &message, sizeof(message), MSG_DONTWAIT, (struct sockaddr *)address.bytes, (socklen_t) address.length);
        }
    }
    
    // If we failed to open a socket, the descriptor will be -1 and it’s safe to
    // close that (it’s guaranteed to fail with `EBADF`).
    close(sock4);
    close(sock6);
}
@end
