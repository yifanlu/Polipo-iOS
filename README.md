This project is a port of [polipo](http://www.pps.jussieu.fr/~jch/software/polipo/) to iOS 6.1+.

libpolipo is an attempt at making polipo into a library. It will not be complete 
until code for de-initialization/cleanup is done. Until then, once polipo is 
initialized, it cannot be cleaned up without restarting the app. This also means 
that you cannot change configuration for polipo without restarting the app.

Polipo-iOS is an iOS GUI wrapper for libpolipo. It supports redirecting polipo 
log output to a UITextView, and also starting/stopping polipo server. You can 
configure polipo through a settings bundle (more options will be added in the 
future). It also supports various backgrounding hacks to run polipo as a 
service. The GUI wrapper portion is licensed under Apache License.
