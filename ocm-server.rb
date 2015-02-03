#!/usr/bin/env macruby

framework 'AppKit'
require 'socket'

@status_item = nil
@app = nil
@port = ARGV[0].nil? ? 65432 : ARGV[0].to_i

def setup_menu
  menu = NSMenu.new
  menu.initWithTitle 'Org Clock Menubar Server'
  mi = NSMenuItem.new
  mi.title = 'Quit Org Clock Menubar Server'
  mi.action = 'stop:'
  mi.target = self
  menu.addItem mi
  menu
end

def init_status_bar(menu)
  status_bar = NSStatusBar.systemStatusBar
  @status_item = status_bar.statusItemWithLength(-1)
  @status_item.setMenu menu
  @status_item.setTitle("")
  @status_item.setToolTip("Org Task Tracker")
end

def stop(sender)
  @app.terminate(nil)
end

def start_server
  puts @port
  ss = TCPServer.new(@port)
  Thread.new do
    loop do
      Thread.start(ss.accept) { |s|
        begin
          while line = s.gets
            @status_item.setTitle(line.strip!) if @status_item
          end
        ensure
          s.close
        end
      }
    end
  end
end

@app = NSApplication.sharedApplication
init_status_bar(setup_menu)
start_server
@app.run
