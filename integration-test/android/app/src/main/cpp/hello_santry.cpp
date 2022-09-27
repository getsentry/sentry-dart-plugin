#include <jni.h>
#include <string>

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_project_project_MainActivity_helloSantry(
        JNIEnv* env,
        jobject /* this */) {
    std::string hello = "Hello Native Santry!";
    return env->NewStringUTF(hello.c_str());
}
