# Miditimer

1. Install the Ruby `micromidi` and `midi-eye` gems.
1. Ensure the interfaces are connected via loopback of some sort (physical cable, software bus loopback, etc) before continuing.
1. Run `ruby miditimer.rb`. It will prompt you to select an input and an output interface, then will go silent for 60 seconds while it generates roughly 1100 MIDI events - a slew of note ons and corresponding note offs a random time later. 

It will print out something like this:

```
*********************
Sent 1204 events, received 1203 successful events back and 0 spurious events. 1 remain unprocessed.
on Average: 3.6ms (Max: 6.4ms | Min: 1.6ms) @ Stdev: 1.2
off Average: 2.2ms (Max: 5.0ms | Min: 1.5ms) @ Stdev: 0.4
total Average: 2.9ms (Max: 6.4ms | Min: 1.5ms) @ Stdev: 1.1
*********************
```

Spurious events show whether the interface generates 'echo' or other MIDI note events for some reason (I've had it happen, that's why I track it). It is normal to see 1-5 events remaining unprocessed - this just means the latency was high enough that when the test stopped the last few notes hadn't come back from the loopback yet. Nothing is wrong there if that number is in the single digits. 

on and off signify timing for note on and off events, I track them separately because I've noticed some interfaces seem to 'accelerate' note off events, not sure why - maybe they transmit before the third byte is reached, assuming the off velocity doesn't matter? No clue. 

Total is the complete set of note on and off event timings.

The values are all differences between the timestamp when the note was put "on the wire" (e.g. sent out the MIDI interface by Ruby) and when the note came back to the Core Midi (or Alsa or whatever you're using) system. The receiving timestamp should be as accurate as the system can make it, and is not (or shouldn't be) dependent on the Ruby code processing it - it should be as close to the "real" time the system received the event as possible. 

# Errors

If you are on linux and get this error when installing the gems:
```
Building native extensions.  This could take a while...
ERROR:  Error installing micromidi:
	ERROR: Failed to build gem native extension.

    current directory: /var/lib/gems/2.3.0/gems/ffi-1.9.25/ext/ffi_c
/usr/bin/ruby2.3 -r ./siteconf20180828-2040-17rgwn5.rb extconf.rb
mkmf.rb can't find header files for ruby at /usr/lib/ruby/include/ruby.h

extconf failed, exit code 1

Gem files will remain installed in /var/lib/gems/2.3.0/gems/ffi-1.9.25 for inspection.
```
It's because you need to also install the ruby-dev packages. Remove and reinstall the gems again after installing ruby-dev.
