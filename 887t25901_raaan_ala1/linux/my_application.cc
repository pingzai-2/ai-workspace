#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// GTK 3.16 后不再推荐 gtk_widget_override_background_color()。
// 用应用级 CSS 设置背景色，避免依赖已弃用的主题覆盖 API。
static void set_widget_background_black(GtkWidget* widget) {
  GtkCssProvider* provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(
      provider, "* { background-color: #000000; }", -1, nullptr);
  gtk_style_context_add_provider(
      gtk_widget_get_style_context(widget), GTK_STYLE_PROVIDER(provider),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(provider);
}

static gint window_dimension_from_environment(const gchar* name,
                                              gint fallback) {
  const gchar* text = g_getenv(name);
  if (text == nullptr || *text == '\0') {
    return fallback;
  }

  gchar* end = nullptr;
  const gint64 value = g_ascii_strtoll(text, &end, 10);
  if (end == text || *end != '\0' || value <= 0 || value > G_MAXINT) {
    return fallback;
  }
  return static_cast<gint>(value);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  set_widget_background_black(GTK_WIDGET(window));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "flutter_home_dashboard_8cun");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "flutter_home_dashboard_8cun");
  }

  const gint window_width =
      window_dimension_from_environment("FLUTTER_WINDOW_WIDTH", 800);
  const gint window_height =
      window_dimension_from_environment("FLUTTER_WINDOW_HEIGHT", 500);
  gtk_window_set_default_size(window, window_width, window_height);
  gtk_window_set_position(window, GTK_WIN_POS_CENTER);
  gtk_window_set_decorated(window, TRUE);
  gtk_window_set_resizable(window, TRUE);
  // Flutter 3.3.7 的 Linux runner 需要先让顶层窗口完成 map，再创建并
  // 挂载 FlView。这样子控件加入已显示容器时会收到有效的首次 configure，
  // 不依赖用户手动拖动窗口触发首帧。
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  set_widget_background_black(GTK_WIDGET(view));
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
