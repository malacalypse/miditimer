require 'date'
require 'ostruct'
require 'midi'
require 'midi-eye'

module Enumerable
    def sum
      self.inject(0){|accum, i| accum + i }
    end

    def mean
      self.sum/self.length.to_f
    end

    def sample_variance
      m = self.mean
      sum = self.inject(0){|accum, i| accum +(i-m)**2 }
      sum/(self.length - 1).to_f
    end

    def standard_deviation
      return Math.sqrt(self.sample_variance)
    end
end

class MidiTimer
  attr_accessor :debug,
                :stack,
                :dead_notes,
                :listener,
                :deltas,
                :channel,
                :input,
                :output

  def initialize
    @listener = nil
    @deltas = { on: [], off: [] }
    @note_off_queue = []
    @dead_notes = []
    @stack = []
    @ref_time = 0
    @channel = 0
    @enqueued = 0
    @dequeued = 0
    @note_off_semaphore = Mutex.new
    @stack_semaphore = Mutex.new

    # First, initialize the MIDI io ports to the first ports by default
    @input = UniMIDI::Input.gets
    @output = UniMIDI::Output.gets

    @debug = false
  end

  def debug?
    @debug == true
  end

  def dequeue(event)
    note = event[:message].note
    velocity = event[:message].is_a?(MIDIMessage::NoteOn) ? event[:message].velocity : 0
    puts "Dequeuing #{event} : [#{note}, #{velocity}]" if debug?
    stack_index = @stack.index { |event| event.note == note && event.velocity == velocity }
    if stack_index.nil?
      puts "Could NOT find event!" if debug?
      @dead_notes << event
      return
    end
    previous = @stack_semaphore.synchronize do
      @stack.delete_at(stack_index)
    end
    update_graph(event, previous)
    @dequeued += 1
  end

  def enqueue(message)
    puts "Enqueuing #{message}" if debug?
    note = message[1]
    velocity = message[0] >= 144 ? message[2] : 0
    @stack_semaphore.synchronize do
      @stack << OpenStruct.new(note: note, velocity: velocity, timestamp: timestamp_ms)
    end
    @output.puts(*message)
    @enqueued += 1
  end

  def update_graph(event, previous_event)
    puts "Calculating offset #{event[:timestamp]} - #{previous_event.timestamp}" if debug?
    delta = event[:timestamp] - previous_event[:timestamp]
    event[:message].is_a?(MIDIMessage::NoteOn) ? @deltas[:on] << delta : @deltas[:off] << delta
  end

  def run(seconds)
    # Initialize the MIDIEye listener and pass it the input port
    @listener.close if @listener&.running?
    @listener&.join
    @listener = MIDIEye::Listener.new(@input)
    @listener.listen_for(:class => [MIDIMessage::NoteOn, MIDIMessage::NoteOff]) { |event| dequeue(event) }

    timer = Thread.new { sleep seconds; puts "Time's up!"; stop }
    @ref_time = timestamp_ms
    @run = true
    @listener.run(background: true)
    generate_stream
    @listener.join
    print_statistics
  end

  def timestamp_ms
    DateTime.now.strftime("%Q").to_i / 1000.0
  end

  def stop
    stop_stream
    @listener.close
  end

  def generate_stream
    @play_stream = Thread.new do
      begin
        play_loop
      rescue Exception => exception
        Thread.main.raise(exception)
      end
    end
    @play_stream.abort_on_exception = true
    @stop_stream = Thread.new do
      begin
        note_off_loop
      rescue Exception => exception
        Thread.main.raise(exception)
      end
    end
    @stop_stream.abort_on_exception = true
    true
  end

  def stop_stream
    @play_stream.kill
    @run = false
    @stop_stream.join
  end

  def play_loop
    loop do
      rest = rand(0.01..0.5)
      number_of_notes = rand(0..5)
      number_of_notes.times do
        note = generate_random_note
        queue_note_off(note, rand(0.1..1))
        enqueue(note)
      end
      sleep(rest)
    end
  end

  def note_off_loop
    loop do
      current_ts = timestamp_ms
      notes = @note_off_semaphore.synchronize do
        notes = @note_off_queue.select { |note| note[:timestamp] <= current_ts }
        @note_off_queue.reject! { |note| note[:timestamp] <= current_ts }
        notes
      end

      notes.each do |note|
        note_off = generate_note_off(note[:note])
        enqueue(note_off)
      end
      break if @run == false && @note_off_queue.size == 0
      sleep(1.0/1000) # approximate 1ms accuracy
    end
  end

  def generate_random_note
    note = rand(10..100)
    velocity = rand(20..120)
    timestamp = DateTime.now.strftime("%Q").to_i
    note_on = 144 + @channel
    [note_on, note, velocity]
  end

  def generate_note_off(note)
    note_off = 128 + @channel
    [note_off, note, 0]
  end

  def queue_note_off(note, millis)
    @note_off_semaphore.synchronize do
      @note_off_queue << { timestamp: timestamp_ms + millis, note: note[1] }
    end
  end

  def print_statistics
    puts "*********************"
    puts "Sent #{@enqueued} events, received #{@dequeued} successful events back and #{@dead_notes.count} spurious events. #{@stack.count} remain unprocessed."

    if @deltas[:on].count.zero? && @deltas[:off].count.zero?
      puts "No statistics gathered!"
      return
    end

    @deltas[:total] = @deltas[:on] + @deltas[:off]
    [:on, :off, :total].each do |ix|
      curr = @deltas[ix]
      average = (curr.mean * 1000).round(1)
      max = (curr.max * 1000).round(1)
      min = (curr.min * 1000).round(1)
      standard_deviation = (curr.standard_deviation * 1000).round(1)
      puts "#{ix.to_s} Average: #{average}ms (Max: #{max}ms | Min: #{min}ms) @ Stdev: #{standard_deviation}"
    end
    puts "*********************"
  end
end

m = MidiTimer.new
m.run 60
