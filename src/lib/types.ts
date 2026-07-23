export type Day = {
  id: string;
  name: string;
  sort_order: number;
};

export type Cue = {
  id: string;
  text: string;
  sort_order: number;
  level: number;
  is_header: boolean;
};

export type Exercise = {
  id: string;
  name: string;
  sort_order: number;
  target_sets: number | null;
  target_reps_low: number | null;
  target_reps_high: number | null;
  cues: Cue[];
};
