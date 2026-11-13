// Restrict RetroArch's per-session command socket to this Mac.
// Only the owned process and the randomly selected command port are affected.
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
static int nexarc_bind(int fd,const struct sockaddr *address,socklen_t length) {
 const char *value=getenv("NEXARC_COMMAND_PORT");
 int port=value?atoi(value):0;
 if(port>0 && address && address->sa_family==AF_INET && length>=sizeof(struct sockaddr_in)) {
  struct sockaddr_in local;memcpy(&local,address,sizeof(local));
  if(ntohs(local.sin_port)==port) {local.sin_addr.s_addr=htonl(INADDR_LOOPBACK);fprintf(stderr,"[NEXARC_COMMANDS] Binding IPv4 command interface to loopback:%d\n",port);return bind(fd,(struct sockaddr*)&local,sizeof(local));}
 }
 if(port>0 && address && address->sa_family==AF_INET6 && length>=sizeof(struct sockaddr_in6)) {
  struct sockaddr_in6 local;memcpy(&local,address,sizeof(local));
  if(ntohs(local.sin6_port)==port) {local.sin6_addr=in6addr_loopback;return bind(fd,(struct sockaddr*)&local,sizeof(local));}
 }
 return bind(fd,address,length);
}
__attribute__((used)) static struct {const void *replacement;const void *original;} nexarc_interpose
__attribute__((section("__DATA,__interpose"))) = {(const void*)nexarc_bind,(const void*)bind};
