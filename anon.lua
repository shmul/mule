require "helpers"

local words = {
  "coconut","lolipop","refreshing","growl","theif","swiftly","tuna","freak","oyster",
  "manatee","pop","candy","tomorow","biscuit","stumble","dislocate","swiss", "classic",
  "maraca","penninsala", "nucleus","ping","twinkle","tinkle","foe","kung","coffee",
  "vigeriously","hyper", "ocho","traffic","irk","sparta","rapid","rampage","original",
  "butter","puppet", "ventriliquist","pac","cake","window","mosquito","guitar","banjo",
  "straw","bicycle", "wood","zuccini","pickle","cucumber","caviare","piano","radish",
  "lobster","blink", "bleep","classy","spanish","charcoal","pie","turtle","zebra",
  "station","plankton", "bulb","meow","pizza","pineapple","spongebob","surge","zues",
  "dentures","protozoa", "cereal","plantae","foolish","animalea","vivid","christmas","goop",
  "gloop","karate", "mythcal","immaturity","symetrical","muffin","injected","rabbit","house",
  "skirt","stone", "wing","banana","tree","chopsticks","glass","weight","mountain",
  "book","girl", "idea","path","salt","nose","paper","river","angel",
  "cloud","engine", "garden","sock","twine","seed","slime","keyboard","shovel",
  "pain","wire", "electricity","locust","dandruff","figure","water","soap","marshmallow",
  "asphalt","death", "ash","mist","gold","comb","oil","hammer","barn",
  "hair","couch", "card","access","acoustic","aftermath","again","alaska","albert",
  "alive","all", "allowed","alumni","am","an","anarchy","and","antelope",
  "anything","apparatus", "architect","army","around","ascent","at","avenu","away",
  "axilla","baby", "babylon","back","backwards","bag","ball","barbecue","bass",
  "bathtub","beauty", "bed","been","below","big","bill","billy","birds",
  "birdwatcher","bittersweet", "black","bliss","blue","blues","bog","bottom","bouncing",
  "bowie","boy", "brain","breathes","brian","bridge","broken","brother","bubble",
  "buffalo","bug", "buried","burn","buses","but","by","bye","camel",
  "carini", "cars","caspian","catapult","cataract","cavern","ceremony","chalkdust",
  "character","clone", "coil","colonel","come","comet","connection","contact","control",
  "could","cousin", "creature","crowd","curtain","dance","dances","dave","david",
  "dear","demand", "den","design","destiny","devil","dinner","dirt",
  "discern","disease", "divided","dog","dogs","dont","down","dr","dream",
  "dreams","drifting", "driver","dung","eliza","end","energy","enough","ent",
  "esther","eye", "face","faced","faht","falls","famous","farmhouse","fast",
  "faulty","feather", "fee","fikus","final","first","fish","flat","flight",
  "fluffs","fluffhead", "fly","foam","folks","food","foot","forbins","forget",
  "frankie","free", "friday","friend","from","fuck","furry","gatekeeper","get",
  "ghost","gin", "glade","glide","golgi","gone","gotta","greenberg","grind",
  "guantanamo","guelah", "guide","gumbo","guy","guyute","ha","hail","halfway",
  "halleys","happy", "harpua","harry","he","heard","heart","heartache","heavy",
  "hippie","hole", "hood","horn","horse","hosemasters","hotel","hydrogen","i",
  "ii","icculus", "ice","if","in","ingest","iniquity","inlaw","insects",
  "into","invisible", "is","its","jaegermeister","jam","jar","jennifer","jibboo",
  "jim","jimmy", "josie","joy","julius","kee","kill","know","landlady",
  "last","lawn", "lazy","left","lengthwise","leprechaun","let","letter","lie",
  "life","lifeboy", "light","like","limb","line","liquid","lizards","llama",
  "log","lushington", "maggies","magilla","mailbox","makisupa","malkenu","man","mango",
  "marbles","mars", "maze","mcgrupp","me","meat","meatstick","melt","mexican",
  "mikes","minkin", "misty","mock","mockingbird","moma","monkey","montana","moon",
  "morning","motel", "mound","mountains","movie","mozambique","mr","mrs","mule",
  "my","n02", "nicu","name","never","no","nothing","number","ocean",
  "ocelot","oh", "one","only","open","over","pa","page","papyrus",
  "part","party", "pebbles","pigtail","piper","plan","policeman","poor","possum",
  "practical","prep", "prince","problem","punch","quadrophonic","reba","reconsidered","red",
  "revenge","revolution", "rift","right","rikers","robert","rocka","roggae","room",
  "round","run", "runaway","running","sail","sample","sand","sanity","saw",
  "says","scared", "scent","scents","school","secret","session","setting","seven",
  "shack","shafty", "show","shrine","silent","simple","sing","skippy","sky",
  "slave","sleep", "sleeping","slick","sloth","smile","so","somantin","song",
  "sounds","sparkle", "spices","splinters","split","spocks","spread","squirming","stash",
  "stealing","steam", "steep","stepped","stole","strange","strut","subtle","sugar",
  "summer","susskind", "suzy","sweet","swept","talk","taste","tela","that",
  "the","theme", "there","these","things","time","to","toe","told",
  "toppling","torture", "train","travels","trucks","tube","unbound","victor","wales",
  "walk","wand", "watchful","whip","who","william","with","wondermouse","wrap",
  "wrong","yellow", "yesterday","you","your","zero","a","for","it",
  "of","on",}

local dict = {}
local function pick_word(orig_)
  if not dict[orig_] then
    function helper()
      for k,v in pairs(words) do
        return k,v
      end
      print("out of words")
      os.exit(1)
    end
    local k,v = helper()
    words[k] = nil
    dict[orig_] = v
  end
  return dict[orig_]
end

local function anonymize_line(line_)
  return string.gsub(line_,"([%w%-%_%.]+)(;%d%w:%d%w)",
                     function(metric,rest)
                       local anons = {}
                       for _,w in ipairs(split(metric,".")) do
                         table.insert(anons,pick_word(w)) end
                       return table.concat(anons,".")..rest
                     end
  )
end

local function anonymize_file(file_)
  with_file(file_..".anon",
            function(f)
              for line in io.lines(file_) do
                local l = anonymize_line(line)
                f:write(anonymize_line(line),"\n")
              end
            end,
            "w+")
end

local function main()
  for _,f in ipairs(arg) do
    anonymize_file(f)
  end
end

main()
