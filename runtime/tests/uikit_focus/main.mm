// Native UIAlertController over a real SDL UIKit window. No game or save data.
#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#import <UIKit/UIKit.h>

static SDL_Window *window;
static UITextField *field;
static Uint64 nextStep;
static int step;

SDL_AppResult SDL_AppInit(void **state, int argc, char **argv) {
  (void)state; (void)argc; (void)argv;
  if (!SDL_Init(SDL_INIT_VIDEO)) return SDL_APP_FAILURE;
  window = SDL_CreateWindow("KartPad Native Text Focus", 800, 400, 0);
  if (!window) return SDL_APP_FAILURE;
  nextStep = SDL_GetTicks() + 1000;
  return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppEvent(void *state, SDL_Event *event) {
  (void)state; (void)event;
  return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate(void *state) {
  (void)state;
  if (SDL_GetTicks() < nextStep) return SDL_APP_CONTINUE;
  nextStep = SDL_GetTicks() + 500;
  if (step == 0) {
    UIWindow *native = (__bridge UIWindow *)SDL_GetPointerProperty(
        SDL_GetWindowProperties(window), SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Set Player Name"
        message:@"Keyboard focus regression fixture" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *text) {
      field = text;
      text.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [native.rootViewController presentViewController:alert animated:NO completion:^{
      [field becomeFirstResponder];
    }];
  } else {
    if (!field.isFirstResponder) {
      SDL_Log("FAIL: native field lost focus at step %d", step);
      return SDL_APP_FAILURE;
    }
    if (step <= 5) [field insertText:@"A"];
    else if (step <= 7) [field deleteBackward];
    else {
      if (![field.text isEqualToString:@"AAA"]) return SDL_APP_FAILURE;
      SDL_Log("PASS: five characters and two backspaces retained native keyboard focus");
      return SDL_APP_SUCCESS;
    }
  }
  ++step;
  return SDL_APP_CONTINUE;
}

void SDL_AppQuit(void *state, SDL_AppResult result) {
  (void)state; (void)result;
  SDL_DestroyWindow(window);
  SDL_Quit();
}
