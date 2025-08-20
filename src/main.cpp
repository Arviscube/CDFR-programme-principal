#include <signal.h>

#include "lidarAnalize.hpp"
#include "lidar.hpp"

#define SIZEDATALIDAR 10000


bool ctrl_c_pressed;
void ctrlc(int)
{
    ctrl_c_pressed = true;
}
bool ctrl_z_pressed = false;
void ctrlz(int signal) {
    ctrl_z_pressed = true;
}


int main(int argc, char *argv[]) {
    LOG_INIT();


    if(!lidarSetup("/dev/ttyAMA0",256000)){
        LOG_ERROR("cannot find the lidar");
        return -1;
    }


    signal(SIGINT, ctrlc);
    signal(SIGTERM, ctrlc);

    lidarAnalize_t lidarData[SIZEDATALIDAR];



    while (1) {

        LOG_SCOPE("Main");
        sleep(0.01);


        int count = SIZEDATALIDAR;
        if(getlidarData(lidarData,count)){
            int x, y, teta;
            int distance;
            //robotI2C->getCoords(x,y,teta);
            x = 0; y = 0; teta = 0;
            position_t position = {x,y,teta,0};
            convertAngularToAxial(lidarData,count,position);
            if(ctrl_z_pressed){
                ctrl_z_pressed = false;
                pixelArtPrint(lidarData,count,50,50,100,position);
            }
            distance = 0;
            int distance_collide = collide(lidarData,count,distance);
        }

        if (ctrl_c_pressed){
            break;
        }
    }

    lidarStop();
    sleep(2);
    LOG_DEBUG("PROCESS KILL");

    return 0;
}