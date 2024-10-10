function onCreate()
end

function onUpdate(dt)

end

function onMessage(message, triggeringActor)
  my.gameControl:handleGridTap(my.layout)
end

my.gameControl = nil