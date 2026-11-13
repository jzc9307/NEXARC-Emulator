// A complete, intentionally small Switch homebrew game.
// Everything visible here is drawn by guest ARM64 code into a Switch framebuffer.
// No ROMs, console keys, firmware, fonts, network, or Nintendo SDK are used.
#include <switch.h>
#include <stdio.h>
#include <string.h>

#define W 1280
#define H 720
static u32 *pixels;
static u32 stride;
static const u32 BG = 0xFF17100C, MINT = 0xFFD5ECA2, CORAL = 0xFF87AEFF, WHITE = 0xFFE9E9E9, MUTED = 0xFF9A8C80;

// A tiny bitmap alphabet keeps the game completely independent of system fonts.
static const unsigned char font[36][7] = {
 {14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},{30,1,1,14,1,1,30},{2,6,10,18,31,2,2},
 {31,16,16,30,1,1,30},{14,16,16,30,17,17,14},{31,1,2,4,8,8,8},{14,17,17,14,17,17,14},{14,17,17,15,1,1,14},
 {14,17,17,31,17,17,17},{30,17,17,30,17,17,30},{14,17,16,16,16,17,14},{30,17,17,17,17,17,30},{31,16,16,30,16,16,31},
 {31,16,16,30,16,16,16},{14,17,16,23,17,17,15},{17,17,17,31,17,17,17},{14,4,4,4,4,4,14},{7,2,2,2,2,18,12},
 {17,18,20,24,20,18,17},{16,16,16,16,16,16,31},{17,27,21,21,17,17,17},{17,25,21,19,17,17,17},{14,17,17,17,17,17,14},
 {30,17,17,30,16,16,16},{14,17,17,17,21,18,13},{30,17,17,30,20,18,17},{15,16,16,14,1,1,30},{31,4,4,4,4,4,4},
 {17,17,17,17,17,17,14},{17,17,17,17,17,10,4},{17,17,17,21,21,21,10},{17,17,10,4,10,17,17},{17,17,10,4,4,4,4},{31,1,2,4,8,16,31}
};
static void rect(int x,int y,int width,int height,u32 color) {
    if(x<0){width+=x;x=0;} if(y<0){height+=y;y=0;}
    if(x+width>W)width=W-x;if(y+height>H)height=H-y;
    for(int yy=y;yy<y+height;yy++)for(int xx=x;xx<x+width;xx++)pixels[yy*stride+xx]=color;
}
static void text(int x,int y,const char *s,int scale,u32 color) {
    for(;*s;s++,x+=6*scale) {
        int index=*s>='0'&&*s<='9'?*s-'0':*s>='A'&&*s<='Z'?*s-'A'+10:-1;
        if(index<0)continue;
        for(int row=0;row<7;row++)for(int col=0;col<5;col++)if(font[index][row]&(1<<(4-col)))rect(x+col*scale,y+row*scale,scale,scale,color);
    }
}
static void circle(int cx,int cy,int radius,u32 color) {
    for(int y=-radius;y<=radius;y++)for(int x=-radius;x<=radius;x++)if(x*x+y*y<=radius*radius)rect(cx+x,cy+y,1,1,color);
}
static float clamp(float value,float min,float max) {return value<min?min:value>max?max:value;}
static void log_message(const char *s){svcOutputDebugString(s,strlen(s));}

int main(int argc,char **argv) {
    (void)argc;(void)argv;
    NWindow *window=nwindowGetDefault();
    Framebuffer framebuffer;
    Result result=framebufferCreate(&framebuffer,window,W,H,PIXEL_FORMAT_RGBA_8888,2);
    if(R_FAILED(result)){log_message("HELIO_PONG_FRAMEBUFFER_FAILED\n");return 1;}
    framebufferMakeLinear(&framebuffer);
    padConfigureInput(1,HidNpadStyleSet_NpadStandard);
    PadState pad;padInitializeDefault(&pad);
    float player=330,computer=330,bx=640,by=360,vx=6,vy=3;
    int score=0,opponent=0,playing=0,frames=0,input_logged=0;
    log_message("HELIO_PONG_READY | framebuffer=1280x720 input=pad\n");
    while(appletMainLoop()) {
        padUpdate(&pad);u64 down=padGetButtonsDown(&pad),held=padGetButtons(&pad);
        if(down&HidNpadButton_Plus)break;
        HidAnalogStickState stick=padGetStickPos(&pad,0);
        float move=-(float)stick.y/32767.0f*8;
        if(held&HidNpadButton_Up)move=-8;if(held&HidNpadButton_Down)move=8;
        player=clamp(player+move,191,532);
        if(move!=0&&!input_logged){log_message("HELIO_PONG_INPUT_RECEIVED\n");input_logged=1;}
        if(down&HidNpadButton_B){score=opponent=0;playing=0;}
        if(!playing&&(down&HidNpadButton_A)) {
            if(score>=5||opponent>=5)score=opponent=0;
            bx=640;by=360;vx=6;vy=3;playing=1;
            log_message("HELIO_PONG_SERVE\n");
        }
        if(playing) {
            bx+=vx;by+=vy;
            if(by<178){by=178;vy=-vy;}if(by>610){by=610;vy=-vy;}
            computer=clamp(computer+clamp(by-(computer+45),-4.4f,4.4f),191,532);
            if(vx<0&&bx<112&&bx>88&&by>player-10&&by<player+100){bx=112;vx=-vx+0.15f;vy=(by-player-45)*0.115f;}
            if(vx>0&&bx>1168&&bx<1192&&by>computer-10&&by<computer+100){bx=1168;vx=-vx-0.15f;vy=(by-computer-45)*0.115f;}
            if(bx<65||bx>1215){if(bx>1215)score++;else opponent++;playing=0;bx=640;by=360;}
            if(score>=5||opponent>=5)playing=0;
        }
        u32 bytes_per_row;pixels=framebufferBegin(&framebuffer,&bytes_per_row);stride=bytes_per_row/sizeof(u32);
        // Draw rows directly; writing the guest framebuffer exercises the graphics path.
        rect(0,0,W,H,BG);
        text(56,37,"HELIO HOMEBREW",2,MINT);
        text(56,77,"ORBIT PONG",6,WHITE);
        text(920,49,"NINTENDO SWITCH",2,MUTED);
        text(920,76,"RUNNING ARM64 CODE",2,MINT);
        rect(56,145,1168,1,0xFF302923);rect(56,640,1168,1,0xFF302923);
        for(int y=174;y<622;y+=26)rect(638,y,3,11,0xFF393029);
        rect(56,165,1168,1,0xFF24201D);rect(56,622,1168,1,0xFF24201D);
        rect(91,(int)player,11,90,MINT);rect(1178,(int)computer,11,90,CORAL);
        circle((int)bx,(int)by,8,WHITE);
        char left[8],right[8];snprintf(left,sizeof(left),"%d",score);snprintf(right,sizeof(right),"%d",opponent);
        text(531,184,left,7,MINT);text(711,184,right,7,CORAL);
        text(75,657,"ARROWS OR LEFT STICK  MOVE",2,MUTED);
        text(75,683,"Z OR SWITCH A  SERVE",2,MUTED);
        text(830,657,"X OR SWITCH B  RESET",2,MUTED);
        text(830,683,"PLUS  QUIT",2,MUTED);
        if(!playing) {
            rect(350,320,580,105,0xFF211A15);
            text(395,342,score>=5?"YOU WIN":opponent>=5?"TRY AGAIN":"READY TO PLAY",4,WHITE);
            text(398,393,"PRESS Z OR SWITCH A TO SERVE",2,CORAL);
        }
        framebufferEnd(&framebuffer);frames++;
        if(frames==30)log_message("HELIO_PONG_FRAMES_PRESENTED count=30\n");
    }
    framebufferClose(&framebuffer);log_message("HELIO_PONG_EXIT\n");return 0;
}
