#include "buses2lication.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = buses2lication_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
