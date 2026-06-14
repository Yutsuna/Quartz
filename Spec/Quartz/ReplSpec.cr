require "../SpecHelper"

describe "crystal i compatibility" do
  it "runs the REPL smoke scenario in the interpreter" do
    output = IO::Memory.new
    status = Process.run(
      "crystal",
      ["i", Path[__DIR__].parent.join("ReplSmoke.cr").to_s],
      output: output,
      error: output,
    )
    status.success?.should be_true
    lines = output.to_s.lines
    lines.should contain(%(#<ReplUser id=1 name="Léo" age=24>))
    lines.should contain("18")
    lines.should contain(%(#<ReplUser id=2 name="Bob" age=18>))
    lines.should contain("1")
    lines.should contain(%({"id" => 1, "name" => "Léo", "age" => 24}))
    lines.should contain(%(["name", "age"]))
    lines.should contain(%(["ReplUser", "ReplAuthor", "ReplBook", "ReplAccount", "ReplHooked", "ReplStamped"]))
    lines.should contain(%({"id":1,"name":"Léo","age":24}))
    lines.should contain(%(#<ReplUser id=0 name="Bob" age=30>))
    lines.should contain(%(#<ReplAuthor id=1 name="Léo">))
    lines.should contain("1")
    lines.should contain("false")
    lines.should contain("true")
    lines.should contain("2")
    lines.should contain("BOB")
    lines.should contain("Time")
  end
end
