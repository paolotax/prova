module LayoutHelper
    def paragraph(&block)
      tag.p class: "max-w-2xl text-lg", &block
    end
  
    def link(name, uri)
      link_to name, uri, target: :_blank, rel: :noreferrer, class: "underline font-semibold"
    end
  
    def sp
      safe_join [ tag.br ] * 2
    end
  
    def content(&block)
      tag.div class: "flex flex-col items-center w-full space-y-8", &block
    end

    def heading(&block)
      tag.header class: "p-4 mb-2 flex justify-between items-center", &block
    end

    def h1(&block)
      tag.h1 class: "text-4xl font-bold", &block
    end

    def h2(text)
      tag.h2 text, class: "text-2xl font-semibold"
    end
      
    def mono(text)
      tag.span text, class: "whitespace-nowrap font-mono font-semibold"
    end
  
    def article(&block)
      tag.article class: "flex flex-col items-center w-full space-y-12", &block
    end
  
    def emphasis(&block)
      tag.p class: "max-w-2xl p-4 text-lg border-2 border-black rounded-lg", &block
    end
end

