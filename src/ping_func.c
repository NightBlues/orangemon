#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <time.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <netdb.h>
#include <netinet/ip_icmp.h>
#include <arpa/inet.h>


int resolve(const char * hostname, struct sockaddr * result) {
  struct addrinfo * addr;
  struct addrinfo hints;
  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = AF_INET;    /* Allow IPv4 or IPv6 */
  hints.ai_socktype = SOCK_RAW;
  hints.ai_flags = AI_PASSIVE;    /* For wildcard IP address */
  hints.ai_protocol = IPPROTO_ICMP;          /* Any protocol */
  hints.ai_canonname = NULL;
  hints.ai_addr = NULL;
  hints.ai_next = NULL;
  if(getaddrinfo(hostname, 0, &hints, &addr) != 0) {
    perror("ping_func: Failed to call getaddrinfo\n");
    return 1;
  }
  /* printf("ping_func: Trying addr: %s, protocol: %d, family: %d\n", addr->ai_canonname, addr->ai_protocol, addr->ai_family); */

  memcpy(result, addr->ai_addr, sizeof(struct sockaddr));
  freeaddrinfo(addr);

  return 0;
}

int wait_sock(const int sock) {
  struct timeval timeout = {3, 0};
  fd_set read_set;
  memset(&read_set, 0, sizeof read_set);
  FD_SET(sock, &read_set);
  int rc = select(sock + 1, &read_set, NULL, NULL, &timeout);
  return rc;
}


int calc_time(const struct timespec * start, const struct timespec * stop) {
  int nanosecs = (int)(stop->tv_nsec - start->tv_nsec);
  int microsecs = nanosecs / 1000;
  return microsecs;
}


int ping_func(const char * hostname, int * result) {
  struct icmphdr icmp_hdr, rcv_hdr;
  struct sockaddr addr;
  int sock;
  unsigned char data[2048];
  struct timespec start, stop;
  int rc; // for return codes

  rc = resolve(hostname, &addr);
  if(rc != 0) {
    return -1;
  }

  sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);

  memset(&icmp_hdr, 0, sizeof(icmp_hdr));
  icmp_hdr.type = ICMP_ECHO;
  icmp_hdr.un.echo.id = 1234; //arbitrary id
  icmp_hdr.un.echo.sequence = 1;

  memcpy(data, &icmp_hdr, sizeof(icmp_hdr));
  memcpy(data + sizeof(icmp_hdr), "hello", 6); //icmp payload
  rc = sendto(sock, data, sizeof(icmp_hdr) + 6, 0,
              &addr, sizeof(addr));
  clock_gettime(CLOCK_REALTIME, &start);
  if(rc <= 0) {
    perror("ping_func: Failed to send icmp echo");
    return -2;
  }

  rc = wait_sock(sock);
  if(rc < 0) {
    perror("ping_func: error with select");
    return -3;
  }
  if(rc == 0) { // timeout exceeded
    *result = 0.0;
    return 0;
  }

  socklen_t slen = 0;
  rc = recvfrom(sock, data, sizeof(data), 0, NULL, &slen);
  if(rc <= 0) {
    perror("ping_func: error with recvfrom");
    return -4;
  }
  if(rc < sizeof(rcv_hdr)) {
    perror("ping_func: error with icmp response");
    return -5;
  }
  memcpy(&rcv_hdr, data, sizeof(rcv_hdr));
  if(rcv_hdr.type != ICMP_ECHOREPLY) {
    printf("ping_func: invalid icmp type 0x%x\n", rcv_hdr.type);
    return -6;
  }
  clock_gettime(CLOCK_REALTIME, &stop);
  *result = calc_time(&start, &stop);
  
  /* int payload_len = rc - sizeof(rcv_hdr); */
  /* int payload_start = sizeof(rcv_hdr); */
  /* char * response = malloc(payload_len); */
  /* memcpy(response, data + payload_start, payload_len); */
  /* printf("Got ICMP response: \"%s\"\n", response); */
  /* free(response); */

  return 0;
}
