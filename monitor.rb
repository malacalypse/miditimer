#!/usr/bin/env ruby
$:.unshift(File.join("..", "lib"))

require "midi-eye"

# This example takes any note messages received from a UniMIDI input,
# and prints them to the console

# First, initialize the MIDI io ports
@input = UniMIDI::Input.gets

# Create a listener for the input port
transpose = MIDIEye::Listener.new(@input)

# Bind an event to the listener using Listener#listen_for
#
transpose.listen_for do |event|

  message = event[:message]
  p message

end

# Start the listener

p "Control-C to quit..."

transpose.run
