// Bridge the public libretro fast-forward override to NEXARC's local UI.
// retro_set_environment is resolved by the host through dlsym for the active
// core. Forward every environment callback unchanged; retain only the host
// entry point so its documented speed override can be called on the main thread.
#include <dlfcn.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <time.h>
#include <stdint.h>
#include <pthread.h>
#include <stdatomic.h>
typedef bool (*nx_environment)(unsigned,void*);
static nx_environment nx_frontend;
typedef void (*nx_video_callback)(const void*,unsigned,unsigned,size_t);
typedef int16_t (*nx_input_callback)(unsigned,unsigned,unsigned,unsigned);
static nx_video_callback nx_video_host;
static nx_input_callback nx_input_host;
static void (*nx_real_set_video)(nx_video_callback);
static void (*nx_real_set_input)(nx_input_callback);
static pthread_mutex_t nx_video_lock=PTHREAD_MUTEX_INITIALIZER;
static unsigned char *nx_video_data;
static size_t nx_video_capacity,nx_video_pitch;
static unsigned nx_video_width,nx_video_height,nx_pixel_format,nx_stored_format;
static _Atomic uint64_t nx_video_frames;
extern bool NXCustomPointer(unsigned id,int16_t *value);
uint64_t NXVideoFrameCount(void){return nx_video_frames;}
static bool nx_capture_enabled(void){const char *v=getenv("NEXARC_CAPTURE_VIDEO");return v&&strcmp(v,"1")==0;}
static bool nx_capture_environment(unsigned command,void *data){if(command==10&&data)nx_pixel_format=*(unsigned*)data;return nx_frontend?nx_frontend(command,data):false;}
static void nx_video(const void *frame,unsigned w,unsigned h,size_t pitch){
 nx_video_frames++;
 if(nx_capture_enabled()&&frame&&frame!=(void*)-1&&w>0&&h>0&&w<=4096&&h<=4096&&pitch>=w*(nx_pixel_format==1?4:2)&&pitch<=65536&&pitch*h<=64*1024*1024){
  size_t bytes=pitch*h;pthread_mutex_lock(&nx_video_lock);
  if(bytes>nx_video_capacity){void *next=realloc(nx_video_data,bytes);if(next){nx_video_data=next;nx_video_capacity=bytes;}}
  if(nx_video_capacity>=bytes){memcpy(nx_video_data,frame,bytes);nx_video_width=w;nx_video_height=h;nx_video_pitch=pitch;nx_stored_format=nx_pixel_format;}
  pthread_mutex_unlock(&nx_video_lock);
 }
 if(frame==(void*)-1){pthread_mutex_lock(&nx_video_lock);nx_video_width=0;nx_video_height=0;pthread_mutex_unlock(&nx_video_lock);}
 if(nx_video_host)nx_video_host(frame,w,h,pitch);
}
static unsigned nx_pad_map[16];
static bool nx_pad_override;
static pthread_once_t nx_pad_once=PTHREAD_ONCE_INIT;
static void nx_init_pad(void){
 for(unsigned i=0;i<16;i++)nx_pad_map[i]=i;
 const char *text=getenv("NEXARC_GAMEPAD_MAP");if(!text)return;
 unsigned parsed[16];const char *cursor=text;
 for(unsigned i=0;i<16;i++){char *end;long value=strtol(cursor,&end,10);if(end==cursor||value<0||value>15||(i<15&&*end!=',')||(i==15&&*end!='\0'))return;parsed[i]=(unsigned)value;cursor=end+1;}
 memcpy(nx_pad_map,parsed,sizeof(parsed));nx_pad_override=true;
}
static int16_t nx_input(unsigned port,unsigned device,unsigned index,unsigned id){
 int16_t value=0;if(port==0&&(device&255)==6&&index==0&&NXCustomPointer(id,&value))return value;
 pthread_once(&nx_pad_once,nx_init_pad);
 if(nx_pad_override&&port==0&&(device&255)==1&&index==0&&nx_input_host){
  if(id<16)return nx_input_host(port,device,index,nx_pad_map[id]);
  if(id==256){uint16_t mask=0;for(unsigned i=0;i<16;i++)if(nx_input_host(port,device,index,nx_pad_map[i]))mask|=(uint16_t)(1u<<i);return (int16_t)mask;}
 }
 return nx_input_host?nx_input_host(port,device,index,id):0;
}
static void nx_set_video(nx_video_callback callback){nx_video_host=callback;if(nx_real_set_video)nx_real_set_video(nx_video);}
static void nx_set_input(nx_input_callback callback){nx_input_host=callback;if(nx_real_set_input)nx_real_set_input(nx_input);}
unsigned char *NXCopyVideoRGBA(unsigned *width,unsigned *height){
 pthread_mutex_lock(&nx_video_lock);unsigned w=nx_video_width,h=nx_video_height;
 if(!nx_video_data||!w||!h){pthread_mutex_unlock(&nx_video_lock);return NULL;}
 unsigned char *out=malloc((size_t)w*h*4);if(!out){pthread_mutex_unlock(&nx_video_lock);return NULL;}
 for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++){
  unsigned r,g,b;const unsigned char *row=nx_video_data+y*nx_video_pitch;
  if(nx_stored_format==1){uint32_t p=((const uint32_t*)row)[x];r=(p>>16)&255;g=(p>>8)&255;b=p&255;}
  else{uint16_t p=((const uint16_t*)row)[x];if(nx_stored_format==2){r=((p>>11)&31)*255/31;g=((p>>5)&63)*255/63;b=(p&31)*255/31;}else{r=((p>>10)&31)*255/31;g=((p>>5)&31)*255/31;b=(p&31)*255/31;}}
  size_t o=((size_t)y*w+x)*4;out[o]=r;out[o+1]=g;out[o+2]=b;out[o+3]=255;
 }
 *width=w;*height=h;pthread_mutex_unlock(&nx_video_lock);return out;
}
static void (*nx_real_run)(void);
static uint64_t nx_frames;
uint64_t NXFrameCount(void){return nx_frames;}
static void nx_run(void){nx_real_run();nx_frames++;}
static void (*nx_real_set_environment)(nx_environment);
static void nx_set_environment(nx_environment frontend){
 if(frontend)nx_frontend=frontend;
 // Preserve the core's original callback identity and all upstream probes.
 if(nx_real_set_environment)nx_real_set_environment(nx_capture_enabled()?nx_capture_environment:frontend);
}
bool NXSetSpeed(int speed){
 if(!nx_frontend)return false;
 if(speed<1||speed>5)return false;
 struct {float ratio;bool fastforward;bool notification;bool inhibit_toggle;} override={(float)speed,speed>1,false,true};
 bool result=nx_frontend(64,&override); // RETRO_ENVIRONMENT_SET_FASTFORWARDING_OVERRIDE
 struct timespec now;clock_gettime(CLOCK_MONOTONIC,&now);
 fprintf(stderr,"[NEXARC_SPEED] %dx override %s frames=%llu time=%.3f\n",speed,result?"accepted":"unavailable",(unsigned long long)nx_frames,now.tv_sec+now.tv_nsec/1e9);return result;
}
static void *nx_dlsym(void *handle,const char *name){
 void *value=dlsym(handle,name);
 if(value&&(strcmp(name,"retro_set_environment")==0||strcmp(name,"retro_run")==0||strcmp(name,"retro_set_video_refresh")==0||strcmp(name,"retro_set_input_state")==0)){
  Dl_info info;const char *selected=getenv("NEXARC_CORE_PATH");char expected[PATH_MAX],actual[PATH_MAX];
  if(selected&&dladdr(value,&info)&&realpath(selected,expected)&&realpath(info.dli_fname,actual)&&strcmp(expected,actual)==0){if(strcmp(name,"retro_set_video_refresh")==0){nx_real_set_video=(void(*)(nx_video_callback))value;return (void*)nx_set_video;}if(strcmp(name,"retro_set_input_state")==0){nx_real_set_input=(void(*)(nx_input_callback))value;return (void*)nx_set_input;}if(strcmp(name,"retro_run")==0){nx_real_run=(void(*)(void))value;return (void*)nx_run;}nx_real_set_environment=(void(*)(nx_environment))value;return (void*)nx_set_environment;}
 }
 return value;
}
__attribute__((used))static struct{const void*replacement;const void*original;}nx_symbol_interpose
__attribute__((section("__DATA,__interpose")))={(const void*)nx_dlsym,(const void*)dlsym};
