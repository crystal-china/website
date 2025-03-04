Hi, Magnus, following is some answers for questions you probably interesting.

We can talk together more details and other stuff during our interview later.

## Tell you about myself

Well, as you can see, I did not majored in Computer Science.
However, I got my first computer around 1998（nineteen ninety-eight), quite early right?

At that time, I have a great interest in using computers, well, I'm a little bit 
lazy and have a poor memory, so, I prefer to automate things as much as possible.

I have a dream of becoming a programmer，however, after use Windows for many years,
I still didn't know much about it, back than，I was so frustrated I couldn't get
Windows to work the way I wanted.

I am a perfectionist，I spent a lot of time deliberating and making choices,
and finally, I realized that Windows just wasn’t for me.

so, in my thrities, I start to use Emacs and Linux, I finally recognized that
this is the things I wanted.

After that, I left my stable, long-time job, taught myself Ruby **seriously** and move to
the big city to began my dreams, so, Ruby is actually the first programming language 
I've used，

After using Ruby for over 10 years, I met Crystal, since than, I started learning 
and using it, up to now.

## Why I use Crystal?

At first, It attracted me through the **Ruby-like syntax**, and **better performance**,
and can built into a binary. but once I started use it, the limit of static typing, 
no abused meta programming, it makes the source code so much easier to read.
The most important feature is `null safety`,  this is the key point I love Crystal. I don't have to spent time writing extra Specs just for refactoring.

## Why I write procodile

Back when I was using Ruby, I built several websites, I used Procodile for both 
local development and deployment. of cause the Ruby version.
I used this gem a lot, but it almost unmaintained,so I created a fork, rewrite it
use Crystal, I think procodile should be a standalone CLI, Crystal is perfect 
because it built to a static binary.

My Crystal skill level up when I was working on porting this gem to Crystal.

At first, I use `su -lc "procodile start -r PROJECT_ROOT" USER` in the `/etc/rc.local` 
to start procodile, altough, later on, I start to use systemd to start procodile.

procodile config is really simple, just a YAML-formatted Procfile for each projects.
systemd is for system services, it can start them up in parallel to speed up boot time.

