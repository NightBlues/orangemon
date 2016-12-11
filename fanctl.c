#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <wiringPi.h>
#include <softPwm.h>

#define BOTTOM_LEVEL 37
#define TOP_LEVEL 43
#define POWER_TOP 255
#define POWER(t) 150
#define CTL_PIN 7
#define DELAY_TIME 2000

void exit_handler(int i) {
  printf("Fan controller stopped...\n");
  digitalWrite(CTL_PIN, LOW);
  exit(0);
}


int get_temp() {
  FILE * fp = fopen("/sys/class/hwmon/hwmon1/temp1_input", "r");
  if(fp == NULL) {
    return -1;
  }
  char buf[5];
  int read_len;
  if((read_len = fread(&buf, 1, 4, fp)) <= 0) {
    return -1;
  }
  buf[read_len] = 0x0;
  fclose(fp);
  int result = atoi(buf);
  if(result <=0 || result > 150) {
    return -2;
  }

  return result;
}


int main() {
  wiringPiSetup();
  // pinMode(CTL_PIN, PWM_OUTPUT);
  softPwmCreate(CTL_PIN, 0, POWER_TOP);

  struct sigaction sa;
  sa.sa_handler = exit_handler;
  sigaction(SIGTERM, &sa, 0);
  sigaction(SIGINT, &sa, 0);
  /* sigset_t newset; */
  /* sigemptyset(&newset); */
  /* sigaddset(&newset, SIGHUP); */
  /* sigprocmask(SIG_BLOCK, &newset, 0); */

  int state = 0;
  while(1) {
    int temp = get_temp();
    if(temp < 0) {
      printf("Error: Could not read cpu temperature value!\n");
    } else if(temp < BOTTOM_LEVEL && state == 1) {
      printf("INFO: Turning off (temp=%d)!\n", temp);
      digitalWrite(CTL_PIN, LOW);
      state = 0;
    } else if(temp >= TOP_LEVEL && state == 0) {
      printf("INFO: Turning on (temp=%d)!\n", temp);
      softPwmWrite(CTL_PIN, POWER(temp));
      state = 1;
    }
    delay(DELAY_TIME);
  }

  return 0;
}
