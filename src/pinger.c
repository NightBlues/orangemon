#include <stdio.h>
#include <unistd.h>
#include <pthread.h>

#include <caml/mlvalues.h>
#include <caml/alloc.h>

#include "ping_func.c"

pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
pthread_t worker;
int times;


void * worker_func(void * arg) {
  while(1) {
    int result;
    int rc = ping_func("yandex.ru", &result);
    printf("ping_func code: %d, result = %d\n", rc, result);
    pthread_mutex_lock(&lock);
    times = result;
    pthread_mutex_unlock(&lock);
    sleep(30);
  }
}


int start_worker() {
  if(pthread_create(&worker, NULL, worker_func, NULL) != 0) {
    printf("Could not create pthread\n");
    return 1;
  }

  return 0;
}


int stop_worker() {
  pthread_join(worker, NULL);
  pthread_mutex_destroy(&lock);

  return 0;
}


int get_times() {
  int times_;
  pthread_mutex_lock(&lock);
  times_ = times;
  pthread_mutex_unlock(&lock);
  return times_;
}


/* int main() { */
/*   start_worker(); */
/*   while(1) { */
/*     sleep(1); */
/*     printf("main thread: value is %d...\n", get_times()); */
/*   } */
/*   stop_worker(); */

/*   return 0; */
/* } */


CAMLprim value start_worker_ml(value unit) {
  start_worker();

  return Val_unit;
}

CAMLprim value get_times_ml(value unit) {
  CAMLprim value result;
  int interval = get_times();
  result = caml_copy_int32(interval);

  return result;
}
