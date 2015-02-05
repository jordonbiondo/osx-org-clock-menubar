#!/usr/bin/env macruby

# Thank you rubiojr: https://gist.github.com/rubiojr/245402

framework 'AppKit'

# Handles drawing the menubar
class OCMView
  def initialize(app)
    @app = app
    menu = setup_menu
    init_status_bar(menu)
    @attrs_dictionary = NSDictionary.dictionaryWithObject(
      NSFont.fontWithName('LucidaGrande', size: 11.0),
      forKey: NSFontAttributeName
    )
  end

  def set_text(text)
    @attr_string = NSAttributedString.alloc.initWithString(text, attributes: @attrs_dictionary)
    @status_item.setHighlightMode(:YES)
    @status_item.setAttributedTitle(@attr_string)
  end

  private

  attr_accessor :app

  def setup_menu
    menu = NSMenu.new
    menu.initWithTitle 'Org Clock Menubar Server'
    mi = NSMenuItem.new
    mi.title = 'Quit Org Clock Menubar Server'
    mi.action = 'stop_action:'
    mi.target = @app.delegate
    menu.addItem mi
    menu
  end

  def init_status_bar(menu)
    status_bar = NSStatusBar.systemStatusBar
    @status_item = status_bar.statusItemWithLength(-1)
    @status_item.setMenu menu
    @status_item.setTitle('')
    @status_item.setToolTip('Org Clock Menubar Server')
  end
end

# Handles client communication
class OCMModel
  require 'socket'
  attr_accessor :server

  def initialize(port)
    @port = port
  end

  def on_change(&block)
    @on_change_hook = block
  end

  def start!
    start_server
  end

  private

  attr_accessor :on_change_hook, :main_thread, :port

  def start_server
    return if @main_thread && @main_thread.alive?
    @server = TCPServer.new(@port)
    @main_thread = Thread.new do
      loop do
        Thread.start(@server.accept) { |s|
          begin
            while line = s.gets
              @on_change_hook.call(line.strip!) if @on_change_hook
            end
          ensure
            s.close
          end
        }
      end
    end
  end
end

class OCMDelegate
  attr_accessor :app

  def initialize(app, view, model)
    @app = app
    view_model_connections(view, model)
  end

  def stop_action(sender)
    @app.terminate(nil)
  end

  private

  def view_model_connections(view, model)
    model.on_change do |line|
      view.set_text(line)
    end
  end

end

class OCMApplication
  attr_accessor :app, :view, :model

  def initialize(port)
    @app = NSApplication.sharedApplication
    @view = OCMView.new(@app)
    @model = OCMModel.new(port)
    @app.delegate = OCMDelegate.new(@app, @view, @model)
  end

  def run!
    @model.start!
    @app.run
  end
end

@port = ARGV[0].nil? ? 65432 : ARGV[0].to_i
ocm_server = OCMApplication.new(@port)
ocm_server.run!
