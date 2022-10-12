# PSNAP
Plummer's Single NIC Access Point

## What is this?
How'd you like to build your own wifi for less than $200?  What if told you that you could do that without gcc and dkms?  You can.

## Why is this?
I'm cheap and lazy.  I should say, I would rather exert myself today in the hopes that I don't have to tomorrow.  Having said that, and having tinkered with openWRT for years, I had the opportunity to research, understand, and develop self healing meshes using HWMP and hostapd on the raspberry pi platform a few years ago.  After that project, I stopped buying custom (and sometimes expensive) wifi routers for my home, and just started making my own.  The repo exists so that I could quickly give something to my college kids to use in the dorm.  All they have to do is plug it in and it goes.

## How is this?
This repo is new, but it was made from another one of mine => PWA (https://github.com/vhsjwp01/pwa).  PWA was based off of ubuntu 18 / debian buster and it required some additional apt sources and ppas to make things work, mostly because of firmware packages for different vendor dongle series.  With the arrival of Ubuntu 22 and Raspbian 11, all of that is unecessary, hence this repo.  The scripts in this repo, once installed, take over networking and create a wan link via the physical ethernet port, and a bridge with the wifi interface (in case one every wants to add more radios or other interfaces for peer visibility), followed by the setup of a dhcp server with a non-colliding privatized IP range for wireless clients.
