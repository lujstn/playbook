function cell(p,m){ return (c[p SUBSEP m]+0) }
function has(list,w,  a,n,i){ n=split(list,a,/[ ,]/); for(i=1;i<=n;i++) if(a[i]==w) return 1; return 0 }
function anyhas(list,want,  a,n,i){ n=split(want,a," "); for(i=1;i<=n;i++) if(has(list,a[i])) return 1; return 0 }
BEGIN{
  EXP["lone-wolf"]="lone-wolf"; EXP["interns"]="interns"; EXP["interns-deadline"]="interns";
  EXP["hackathon"]=(teams=="off" ? "hackathon interns" : "hackathon"); EXP["workflows"]="workflows";
  EXP["gsd"]="gsd"; EXP["boundary-a"]="lone-wolf interns"; EXP["boundary-b"]="workflows";
  EXP["workflows-large"]="workflows"; EXP["workflows-feature"]="workflows"
}
NR>1 {
  p=$1; canary=$3; m=$4; beh=$6; cost=$7;
  tcost+=cost; n++;
  if(canary!="yes"){ void++; next }
  if(m=="censored"){ cens++; next }
  scored++; c[p SUBSEP m]++;
  src[$10]++;
  if(m!="malformed" && m!="none"){ recn++; if(has(EXP[p],m)) recok++ }
  if(($10=="picker"||$10=="route") && m!="malformed"){ shn++; if(anyhas($11,EXP[p])) shok++ }
  refused+=$12;
  if($9=="exact") mapex++; else if($9=="loose") maplo++; else if($9=="wrong") mapwr++;
  multi=(m=="interns"||m=="hackathon"||m=="workflows"); solo=(beh=="solo");
  if(multi&&solo) div++; if(m=="lone-wolf"&&!solo) div++;
  if(m=="malformed") malf++;
  if($10=="picker"){ pk++; if(split($11,z,",")==4) pk4++ }
  if(p=="interns"){ midexp++;
    if(m=="interns"||m=="hackathon") midhit++;
    if(m=="lone-wolf"||m=="workflows") poleleak++; }
}
END{
  split("lone-wolf interns hackathon workflows gsd none malformed", COL, " ");
  nrow=split("lone-wolf interns hackathon workflows workflows-feature gsd boundary-a boundary-b", ROW, " ");
  printf "CONFUSION MATRIX (rows=prompt, cols=announced marker)\n";
  printf "%-17s %3s %3s %3s %3s %3s %4s %4s\n","", "LW","IN","HK","WF","GSD","none","malf";
  for(i=1;i<=nrow;i++){ p=ROW[i];
    printf "%-17s %3d %3d %3d %3d %3d %4d %4d\n", p,
      cell(p,"lone-wolf"),cell(p,"interns"),cell(p,"hackathon"),
      cell(p,"workflows"),cell(p,"gsd"),cell(p,"none"),cell(p,"malformed"); }
  printf "\nMETRICS (scored=%d, void=%d, censored=%d)\n", scored, void+0, cens+0;
  if(cens) print "  censored = hit the turn cap before announcing a route; raise MAX_TURNS and re-run those";
  printf "  middle-occupancy   %d/%d  (the interns prompt landing interns/hackathon)\n", midhit+0, midexp+0;
  printf "  pole-leakage       %d/%d  (same prompts landing lone-wolf/workflows)\n", poleleak+0, midexp+0;
  printf "  marker!=behaviour  %d/%d  (route announced vs dispatch actually reached)\n", div+0, scored+0;
  printf "  1:1 mode mapping   exact=%d loose=%d wrong=%d  (announced mode vs mode-exact tool signature)\n", mapex+0, maplo+0, mapwr+0;
  printf "  malformed markers  %d/%d\n", malf+0, scored+0;
  printf "  decision source    picker=%d route=%d marker=%d none=%d\n", src["picker"]+0, src["route"]+0, src["marker"]+0, src["none"]+0;
  printf "  recommended/route in expected set    %d/%d\n", recok+0, recn+0;
  printf "  shortlist contains an expected mode  %d/%d  (picker and route rows only)\n", shok+0, shn+0;
  printf "  pickers offering four ranked modes   %d/%d\n", pk4+0, pk+0;
  printf "  refused route lines  %d  (the hooks refused a malformed route line before the accepted one)\n", refused+0;
  printf "  total cost         $%.2f   avg $%.3f/run\n", tcost+0, (n?tcost/n:0);
  if(teams=="off") print "  note: hackathon handicapped (teams flag off) - fall-back expected, not a pole-jump";
}
