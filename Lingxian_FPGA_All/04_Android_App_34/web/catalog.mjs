export const catalog={version:1,scores:[
 {id:'twinkle',title:'小星星练习片段',bpm:120,steps:[0,4,5,4,3,2,1,0,4,3,2,1,4,3,2,1].flatMap(note=>[{note,ticks:2},{note,ticks:2}])},
 {id:'scale',title:'C大调上下行',bpm:90,steps:[0,1,2,3,4,5,6,5,4,3,2,1,0,255].map(note=>({note,ticks:2}))},
 {id:'rhythm',title:'长短音与休止练习',bpm:100,steps:[{note:0,ticks:1},{note:1,ticks:1},{note:2,ticks:2},{note:255,ticks:2},{note:4,ticks:4},{note:0,ticks:2}]}
]};
