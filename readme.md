# 🍲 Soup

Soup is a messy, simple, tasty, framework thing for game development, sitting on top of love2d. For lack of something more original, I'm calling it an "entity behaviour system".

Its core design is motivated by the observation that when making [arco](https://arco.game) with [ferris](https://github.com/1bardesign/ferris) I tended to use behaviours - simple update/draw data structures - for the vast majority of functionality, only reaching for systems when something complex needed a bit of extra optimisation. I also hit a few snags with draw ordering where it was a real pain to interleave drawing across systems.

With soup, I'm leaning into behaviours, including making systems just be special case behaviours. I'll provide a few examples but I believe this is actually a form of returning to my roots - Flixel (which i used for a lot of my early game development) is based around "just" update and draw functions and they are definitely enough to make games with.

Soup is more based on composition than those fairly strict OOP frameworks, but is a lot less implicit about it than a normal ECS approach - for example, if you want to share positions between behaviours then you will need to do so manually. I have found in practice this is a non-issue.

# Clarifying "Entity Behaviour System"

Entities are "game objects"; a collection of behaviours acting together as one thing that can be cleaned up all together.

Behaviours are the nuts and bolts of an entity; they may be a sprite or a physics shape or handle input or do something based on timing. At their core, they are a data structure that may be updated or drawn.

Systems are meta-behaviours that do some operation in aggregate or provide functionality for multiple entities. Think Physics, UI, Game Rules, that sort of thing.