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

    def h2(&block)
      tag.h2 class: "text-xl font-semibold pt-5 pb-1 px-4", &block
    end
      
    def mono(text)
      tag.span text, class: "whitespace-nowrap font-mono font-semibold"
    end
  
    def article(&block)
      tag.article class: "flex flex-col items-center w-full space-y-12", &block
    end
  
    def emphasis(&block)
      tag.div class: "italic text-gray-800 my-2 pl-2 text-lg border-l-4 border-gray-300", &block
    end
end

