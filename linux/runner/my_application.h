#ifndef FLUTTER_buses2LICATION_H_
#define FLUTTER_buses2LICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication, buses2lication, MY, APPLICATION,
                     GtkApplication)

/**
 * buses2lication_new:
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* buses2lication_new();

#endif  // FLUTTER_buses2LICATION_H_
